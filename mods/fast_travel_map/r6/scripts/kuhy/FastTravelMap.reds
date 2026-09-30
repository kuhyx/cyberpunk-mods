// (d) The fast-travel map behaves exactly like the regular map: same quick
// filter, tracked-quest panel and waypoint hint, no "select destination" box,
// and right-click places/removes a waypoint instead of closing the menu.
// Hold-to-fast-travel on a fast-travel point is untouched; Esc/B closes.
module Kuhy.FastTravelMap

// Vanilla forces the FastTravel quick filter here; restore the filter the
// menu was initialised with (the one saved by the regular map).
@wrapMethod(WorldMapMenuGameController)
protected cb func OnEntityAttached() -> Bool {
  let savedFilter: gamedataWorldMapFilter = this.GetQuickFilter();
  let result: Bool = wrappedMethod();
  if this.IsFastTravelEnabled() {
    this.SetQuickFilter(savedFilter);
    this.UpdateFastTravelVisiblity(false);
    this.UpdateTrackedQuest();
    this.RefreshInputHints();
  };
  return result;
}

// Vanilla only persists filter changes made on the regular map.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnUninitialize() -> Bool {
  if this.IsFastTravelEnabled() {
    this.SaveFilters();
  };
  return wrappedMethod();
}

// Right-click sets m_pressedRMB before the menu's back event arrives -- the
// same signal the regular (hub) map uses to stay open. In fast-travel mode
// the controller now decides whether to close.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnBack(userData: ref<IScriptable>) -> Bool {
  if !this.IsFastTravelEnabled() {
    return wrappedMethod(userData);
  };
  let pressedRMB: Bool = this.m_pressedRMB;
  this.m_pressedRMB = false;
  if !pressedRMB {
    this.PlaySound(n"Button", n"OnPress");
    this.m_menuEventDispatcher.SpawnEvent(n"OnKuhyCloseFastTravel");
  };
  return true;
}

// Closing is routed through the map controller above (Esc, B, and the
// OnBack that vanilla FastTravel() spawns after a successful travel).
@replaceMethod(MenuScenario_FastTravel)
protected cb func OnBack() -> Bool {
  return true;
}

@addMethod(MenuScenario_FastTravel)
protected cb func OnKuhyCloseFastTravel() -> Bool {
  this.GotoIdleState();
  return true;
}

// Vanilla body minus the fast-travel early return.
@replaceMethod(WorldMapMenuGameController)
private final func TryTrackQuestOrSetWaypoint() -> Void {
  if this.IsDelamainTaxiEnabled() {
    this.TrackDelamainTaxiMappin();
    this.UpdateTravelDestination();
    this.UpdateSelectedMappinTooltip();
  } else {
    if this.selectedMappin != null {
      if this.selectedMappin.IsDelamainTaxiTracked() {
        return;
      };
      if this.selectedMappin.IsInCollection() && this.selectedMappin.IsCollection() || !this.selectedMappin.IsInCollection() {
        if this.CanQuestTrackMappin(this.selectedMappin) {
          if !this.IsMappinQuestTracked(this.selectedMappin) {
            this.UntrackCustomPositionMappin();
            this.TrackQuestMappin(this.selectedMappin);
            this.PlaySound(n"MapPin", n"OnEnable");
            this.PlayRumble(RumbleStrength.SuperLight, RumbleType.Slow, RumblePosition.Right);
          };
        } else {
          if this.CanPlayerTrackMappin(this.selectedMappin) {
            if this.selectedMappin.IsCustomPositionTracked() {
              this.UntrackCustomPositionMappin();
              this.SetSelectedMappin(null);
              this.PlaySound(n"MapPin", n"OnDisable");
              this.PlayRumble(RumbleStrength.SuperLight, RumbleType.Pulse, RumblePosition.Right);
            } else {
              if this.selectedMappin.IsPlayerTracked() && this.selectedMappin.IsDelamainTaxiTracked() {
                this.UntrackMappin();
                this.PlaySound(n"MapPin", n"OnDisable");
                this.PlayRumble(RumbleStrength.SuperLight, RumbleType.Pulse, RumblePosition.Right);
              } else {
                this.UntrackCustomPositionMappin();
                this.TrackMappin(this.selectedMappin);
                this.PlaySound(n"MapPin", n"OnEnable");
                this.PlayRumble(RumbleStrength.SuperLight, RumbleType.Slow, RumblePosition.Right);
              };
            };
          };
        };
        this.UpdateSelectedMappinTooltip();
      };
    } else {
      this.TrackCustomPositionMappin();
    };
  };
  this.PlaySound(n"MapPin", n"OnCreate");
}

// Vanilla body minus the fast-travel early return (Delamain taxi keeps it).
@replaceMethod(WorldMapMenuGameController)
private final func UpdateTrackedQuest() -> Void {
  let hasTrackedQuest: Bool;
  let isQuestType: Bool;
  let questType: gameJournalQuestType;
  let trackedPhase: wref<JournalQuestPhase>;
  ArrayClear(this.m_mappinsPositions);
  if this.IsDelamainTaxiEnabled() {
    return;
  };
  this.m_trackedObjective = this.m_journalManager.GetTrackedEntry() as JournalQuestObjectiveBase;
  if this.m_trackedObjective != null {
    inkTextRef.SetText(this.m_objectiveName, this.m_trackedObjective.GetDescription());
    this.m_mappinSystem.GetQuestMappinPositionsByObjective(Cast<Uint32>(this.m_journalManager.GetEntryHash(this.m_trackedObjective)), this.m_mappinsPositions);
    trackedPhase = this.m_journalManager.GetParentEntry(this.m_trackedObjective) as JournalQuestPhase;
    if trackedPhase != null {
      this.m_trackedQuest = this.m_journalManager.GetParentEntry(trackedPhase) as JournalQuest;
      if this.m_trackedQuest != null {
        inkWidgetRef.SetVisible(this.m_questContainer, true);
        inkTextRef.SetText(this.m_questName, this.m_trackedQuest.GetTitle(this.m_journalManager));
        hasTrackedQuest = true;
        questType = this.m_journalManager.GetQuestType(this.m_trackedQuest);
        isQuestType = Equals(questType, gameJournalQuestType.MainQuest) || Equals(questType, gameJournalQuestType.SideQuest) || Equals(questType, gameJournalQuestType.CourierSideQuest) || Equals(questType, gameJournalQuestType.MinorQuest);
        if isQuestType {
          inkWidgetRef.SetState(this.m_questName, n"Quest");
          inkWidgetRef.SetState(this.m_objectiveFrame, n"Quest");
        } else {
          inkWidgetRef.SetState(this.m_questName, n"Gigs");
          inkWidgetRef.SetState(this.m_objectiveFrame, n"Gigs");
        };
      };
    };
  };
  inkWidgetRef.SetVisible(this.m_questContainer, hasTrackedQuest);
}

// Vanilla hides the waypoint hint in fast-travel mode; show it everywhere.
@replaceMethod(WorldMapMenuGameController)
private final func RefreshInputHints() -> Void {
  let priority: Int32 = 1;
  let evt: ref<UpdateInputHintMultipleEvent> = new UpdateInputHintMultipleEvent();
  evt.targetHintContainer = n"WorldMapInputHints";
  if this.IsEntitySetup() {
    this.AddInputHintUpdate(evt, true, n"CloseMenuSingleKey", "Common-Access-Close", priority);
    if (this.selectedMappin as WorldMapPlayerMappinController) == null {
      this.AddInputHintUpdate(evt, true, n"world_map_menu_jump_to_player", "UI-ScriptExports-JumpToPlayer0", priority);
    } else {
      this.AddInputHintUpdate(evt, ArraySize(this.m_mappinsPositions) > 0, n"world_map_menu_jump_to_player", "UI-UserActions-JumpToObjective", priority);
    };
    this.AddInputHintUpdate(evt, true, n"world_map_menu_zoom_in", "Gameplay-RPG-Stats-WeaponStats-ZoomLevel", priority);
    this.AddInputHintUpdate(evt, true, n"world_map_fake_move", "Gameplay-Player-ButtonHelper-Move", priority);
    this.AddInputHintUpdate(evt, true, n"world_map_menu_track_waypoint", "UI-Settings-ButtonMappings-Actions-MapTrack", priority);
    this.QueueEvent(evt);
  };
}
