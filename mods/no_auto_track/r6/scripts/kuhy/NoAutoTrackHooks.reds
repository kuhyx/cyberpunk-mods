// Every script path a player uses to change tracking. Each one opens the
// NoAutoTrack intent window before the vanilla code runs.
module Kuhy.NoAutoTrack

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let system: ref<NoAutoTrackSystem> = NoAutoTrackSystem.Get(this.GetGame());
  if IsDefined(system) {
    system.OnPlayerAttached();
  };
  return result;
}

// Journal: "Track" / "Untrack" on a quest.
@wrapMethod(questLogGameController)
protected cb func OnRequestChangeTrackedObjective(e: ref<RequestChangeTrackedObjective>) -> Bool {
  KuhyMarkTrackIntent(this.m_game);
  return wrappedMethod(e);
}

// Map: right-click / gamepad "track" on a quest or POI pin.
@wrapMethod(WorldMapMenuGameController)
private final func HandlePressInput(e: ref<inkPointerEvent>) -> Void {
  if e.IsAction(n"world_map_menu_track_waypoint") {
    KuhyMarkTrackIntent(this.GetPlayerControlledObject().GetGame());
  };
  wrappedMethod(e);
}

// Journal/phone UI helper used by several menus.
@wrapMethod(JournalWrapper)
public final func SetTracking(entry: wref<JournalEntry>) -> Void {
  KuhyMarkTrackIntent(GetGameInstance());
  wrappedMethod(entry);
}

// "Track" button on a new-quest notification.
@wrapMethod(TrackQuestNotificationAction)
public func Execute(data: ref<IScriptable>) -> Bool {
  KuhyMarkTrackIntent(GetGameInstance());
  return wrappedMethod(data);
}

// "Track" on a quest attached to a phone message.
@wrapMethod(PhoneMessagePopupGameController)
private final func TrackQuest() -> Void {
  KuhyMarkTrackIntent(GetGameInstance());
  wrappedMethod();
}

// D-pad "cycle objectives".
@wrapMethod(CycleObjectiveEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  KuhyMarkTrackIntent(scriptInterface.GetGame());
  wrappedMethod(stateContext, scriptInterface);
}
