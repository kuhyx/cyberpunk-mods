// (f) While your radio plays (car radio while you are in the car, or the
// pocket radio), combat does not fade it out and no combat music starts.
// With no radio on, combat music behaves as in vanilla. Turning the radio on
// or off mid-fight switches over within a second.
//
// The fade is the audio engine's reaction to the "EnterCombat" game tone that
// PlayerCombatController sends, so this mod withholds that tone (and its
// matching "LeaveCombat") whenever a radio is playing.
module Kuhy.RadioInCombat

public class RadioInCombatSystem extends ScriptableSystem {
  private let m_player: wref<PlayerPuppet>;
  private let m_inCombat: Bool;
  // Whether the audio engine was told "EnterCombat" and not yet "LeaveCombat".
  private let m_toneSent: Bool;
  private let m_polling: Bool;

  private final const func PollSeconds() -> Float = 1.0

  public final static func Get(game: GameInstance) -> ref<RadioInCombatSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"Kuhy.RadioInCombat.RadioInCombatSystem") as RadioInCombatSystem;
  }

  public final func OnCombatChanged(player: wref<PlayerPuppet>, inCombat: Bool) -> Void {
    this.m_player = player;
    this.m_inCombat = inCombat;
    this.Sync();
    if inCombat && !this.m_polling {
      this.m_polling = true;
      this.SchedulePoll();
    };
  }

  public final func Poll() -> Void {
    this.m_polling = this.m_inCombat;
    if !this.m_polling {
      return;
    };
    this.Sync();
    this.SchedulePoll();
  }

  private final func SchedulePoll() -> Void {
    let callback: ref<RadioInCombatPoll> = new RadioInCombatPoll();
    callback.m_system = this;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(callback, this.PollSeconds(), false);
  }

  // Combat music wanted = in combat and no radio playing; send the tone
  // that moves the audio engine to that state, once per transition.
  private final func Sync() -> Void {
    let wantTone: Bool = this.m_inCombat && !this.IsRadioPlaying();
    if Equals(wantTone, this.m_toneSent) {
      return;
    };
    this.m_toneSent = wantTone;
    GameInstance.GetAudioSystem(this.GetGameInstance()).NotifyGameTone(wantTone ? n"EnterCombat" : n"LeaveCombat");
    ModLog(n"Kuhy.RadioInCombat", wantTone ? "combat music on" : "combat music off (radio playing or combat over)");
  }

  private final func IsRadioPlaying() -> Bool {
    let vehicle: ref<VehicleObject>;
    let player: ref<PlayerPuppet> = this.m_player;
    if !IsDefined(player) {
      return false;
    };
    vehicle = player.GetMountedVehicle();
    if IsDefined(vehicle) && vehicle.IsRadioReceiverActive() {
      return true;
    };
    return IsDefined(player.GetPocketRadio()) && player.GetPocketRadio().IsActive();
  }
}

public class RadioInCombatPoll extends DelayCallback {
  public let m_system: wref<RadioInCombatSystem>;

  public func Call() -> Void {
    if IsDefined(this.m_system) {
      this.m_system.Poll();
    };
  }
}

// Vanilla ActivateCombat with the EnterCombat tone handed to the system.
@replaceMethod(PlayerCombatController)
private final func ActivateCombat() -> Void {
  this.SetBlackboardIntVariable(GetAllBlackboardDefs().PlayerStateMachine.Combat, 1);
  this.SendAnimFeatureData(true);
  PlayerPuppet.ReevaluateAllBreathingEffects(this.m_owner as PlayerPuppet);
  if !IsMultiplayer() && !Cast<Bool>(GetFact(this.m_owner.GetGame(), n"story_mode")) && !this.m_owner.IsReplacer() {
    GameInstance.GetStatPoolsSystem(this.m_owner.GetGame()).RequestSettingModifierWithRecord(Cast<StatsObjectID>(this.m_owner.GetEntityID()), gamedataStatPoolType.Health, gameStatPoolModificationTypes.Regeneration, t"BaseStatPools.PlayerBaseInCombatHealthRegen");
  };
  FastTravelSystem.AddFastTravelLock(n"InCombat", this.m_owner.GetGame());
  ChatterHelper.TryPlayEnterCombatChatter(this.m_owner);
  RadioInCombatSystem.Get(this.m_owner.GetGame()).OnCombatChanged(this.m_owner as PlayerPuppet, true);
  GameInstance.GetAudioSystem(this.m_owner.GetGame()).HandleCombatMix(this.m_owner);
  if !this.GetBoolFromQuestDB(n"block_combat_scripts_tutorials") && this.IsRightHandInUnequippedState() && !this.GetBoolFromQuestDB(n"disable_tutorials") {
    this.TutorialSetFact(n"combat_tutorial");
  };
  GameObjectEffectHelper.BreakEffectLoopEvent(this.m_owner, n"stealth_mode");
}

// Vanilla ActivateOutOfCombat with the LeaveCombat tone handed to the system.
@replaceMethod(PlayerCombatController)
private final func ActivateOutOfCombat() -> Void {
  this.SetBlackboardIntVariable(GetAllBlackboardDefs().PlayerStateMachine.Combat, 2);
  this.SendAnimFeatureData(false);
  PlayerPuppet.ReevaluateAllBreathingEffects(this.m_owner as PlayerPuppet);
  if !IsMultiplayer() && ScriptedPuppet.IsActive(this.m_owner) {
    GameInstance.GetStatPoolsSystem(this.m_owner.GetGame()).RequestSettingModifierWithRecord(Cast<StatsObjectID>(this.m_owner.GetEntityID()), gamedataStatPoolType.Health, gameStatPoolModificationTypes.Regeneration, t"BaseStatPools.PlayerBaseOutOfCombatHealthRegen");
  };
  ChatterHelper.TryPlayLeaveCombatChatter(this.m_owner);
  RadioInCombatSystem.Get(this.m_owner.GetGame()).OnCombatChanged(this.m_owner as PlayerPuppet, false);
  GameInstance.GetAudioSystem(this.m_owner.GetGame()).HandleOutOfCombatMix(this.m_owner);
  FastTravelSystem.RemoveFastTravelLock(n"InCombat", this.m_owner.GetGame());
  GameObjectEffectHelper.BreakEffectLoopEvent(this.m_owner, n"stealth_mode");
}
