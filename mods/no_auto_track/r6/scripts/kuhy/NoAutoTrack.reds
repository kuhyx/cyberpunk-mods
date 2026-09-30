// (c) Quest tracking changes only when the player asks. Any switch the game
// makes on its own -- next quest after a completion, a new quest, gig or
// fixer call, main-quest re-tracking -- is reverted. The one exception: the
// tracked quest moving on to its next objective stays tracked.
//
// The game's auto-tracking is native (quest graph nodes), so it cannot be
// intercepted; instead every script path a player uses to track something
// opens a short "player intent" window, and the Tracked journal callback
// reverts any change that arrives outside one.
module Kuhy.NoAutoTrack

import Kuhy.Common.*

public class NoAutoTrackSystem extends ScriptableSystem {
  private let m_journal: wref<JournalManager>;
  // Top-level quest the player chose (0 = nothing tracked on purpose).
  private let m_userQuestHash: Int32;
  // Engine time until which tracking changes count as the player's own.
  private let m_intentUntil: Float;

  // Player intent lasts this long; the journal callback lands well inside.
  private final const func IntentSeconds() -> Float = 1.0
  // After a load the game restores/re-tracks the saved quest; adopt it.
  private final const func LoadGraceSeconds() -> Float = 10.0

  public final static func Get(game: GameInstance) -> ref<NoAutoTrackSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"Kuhy.NoAutoTrack.NoAutoTrackSystem") as NoAutoTrackSystem;
  }

  private func OnAttach() -> Void {
    this.m_journal = GameInstance.GetJournalManager(this.GetGameInstance());
    this.m_journal.RegisterScriptCallback(this, n"OnTrackedEntryChanges", gameJournalListenerType.Tracked);
    this.OpenIntent(this.LoadGraceSeconds());
  }

  private func OnDetach() -> Void {
    this.m_journal.UnregisterScriptCallback(this, n"OnTrackedEntryChanges");
  }

  public final func OnPlayerAttached() -> Void {
    this.OpenIntent(this.LoadGraceSeconds());
    this.m_userQuestHash = this.QuestHashOf(this.m_journal.GetTrackedEntry());
  }

  public final func MarkPlayerIntent() -> Void {
    this.OpenIntent(this.IntentSeconds());
  }

  private final func Now() -> Float {
    return EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
  }

  private final func OpenIntent(seconds: Float) -> Void {
    this.m_intentUntil = MaxF(this.m_intentUntil, this.Now() + seconds);
  }

  protected cb func OnTrackedEntryChanges(hash: Uint32, className: CName, notifyOption: JournalNotifyOption, changeType: JournalChangeType) -> Bool {
    let questHash: Int32 = this.QuestHashOf(this.m_journal.GetTrackedEntry());
    if this.Now() <= this.m_intentUntil {
      this.m_userQuestHash = questHash;
      return true;
    };
    if questHash == this.m_userQuestHash {
      return true;
    };
    KuhyLog(n"Kuhy.NoAutoTrack", s"reverting automatic track of quest \(questHash) (player chose \(this.m_userQuestHash))");
    this.RestorePlayerChoice();
    return true;
  }

  // Re-track the player's quest if it is still running, otherwise untrack.
  // Either call re-enters OnTrackedEntryChanges with the player's quest (or
  // nothing) tracked, which matches m_userQuestHash, so it cannot loop.
  private final func RestorePlayerChoice() -> Void {
    let objective: wref<JournalEntry>;
    let questEntry: wref<JournalEntry>;
    if this.m_userQuestHash != 0 {
      questEntry = this.m_journal.GetEntry(Cast<Uint32>(this.m_userQuestHash));
      if IsDefined(questEntry) && Equals(this.m_journal.GetEntryState(questEntry), gameJournalEntryState.Active) {
        objective = this.FirstActiveObjective(questEntry);
        if IsDefined(objective) {
          this.m_journal.TrackEntry(objective);
          return;
        };
      };
    };
    this.m_userQuestHash = 0;
    this.m_journal.UntrackEntry();
  }

  private final func FirstActiveObjective(questEntry: wref<JournalEntry>) -> wref<JournalEntry> {
    let filter: JournalRequestStateFilter;
    let objectives: array<wref<JournalEntry>>;
    let phases: array<wref<JournalEntry>>;
    let i: Int32 = 0;
    filter.active = true;
    this.m_journal.GetChildren(questEntry, filter, phases);
    while i < ArraySize(phases) {
      ArrayClear(objectives);
      this.m_journal.GetChildren(phases[i], filter, objectives);
      if ArraySize(objectives) > 0 {
        return objectives[0];
      };
      i += 1;
    };
    return null;
  }

  // Hash of the top-level quest owning an entry (the entry itself if it is
  // a quest); 0 when nothing is tracked.
  private final func QuestHashOf(entry: wref<JournalEntry>) -> Int32 {
    let questEntry: wref<JournalQuest>;
    if !IsDefined(entry) {
      return 0;
    };
    questEntry = questLogGameController.GetTopQuestEntry(this.m_journal, entry);
    if !IsDefined(questEntry) {
      questEntry = entry as JournalQuest;
    };
    return IsDefined(questEntry) ? this.m_journal.GetEntryHash(questEntry) : 0;
  }
}

public static func KuhyMarkTrackIntent(game: GameInstance) -> Void {
  let system: ref<NoAutoTrackSystem> = NoAutoTrackSystem.Get(game);
  if IsDefined(system) {
    system.MarkPlayerIntent();
  };
}
