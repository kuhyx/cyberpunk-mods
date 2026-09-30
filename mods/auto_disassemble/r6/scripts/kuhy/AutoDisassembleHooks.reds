// Entry points for AutoDisassemble: pickups, save loads, inventory button.
module Kuhy.AutoDisassemble

// Pickups only: anything added while a menu is open is a purchase, a craft,
// a stash transfer or a removed mod -- the player's deliberate choice.
@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let uiSystem: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGame()).Get(GetAllBlackboardDefs().UI_System);
  if ItemID.IsValid(evt.itemID) && !evt.flaggedAsSilent && !uiSystem.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu) {
    AutoDisassembleSystem.Get(this.GetGame()).SchedulePickup(this, evt.itemID);
  };
  return result;
}

// One sweep after each load, once the inventory and wardrobe are restored.
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let system: ref<AutoDisassembleSystem> = AutoDisassembleSystem.Get(this.GetGame());
  if IsDefined(system) {
    system.ScheduleSweep(this, 5.0);
  };
  return result;
}

// Inventory "Disassemble Junk" button: confirm, then disassemble everything
// the rules allow (junk included), not just junk.
@replaceMethod(BackpackMainGameController)
protected cb func OnDisassembleJunkButtonClick(e: ref<inkPointerEvent>) -> Bool {
  let eligible: array<wref<gameItemData>>;
  if e.IsAction(n"click") {
    eligible = AutoDisassembleSystem.Get(this.m_player.GetGame()).Eligible(this.m_player);
    if ArraySize(eligible) == 0 {
      this.ShowNotification(this.m_player.GetGame(), UIMenuNotificationType.NoJunkToDisassemble);
      this.PlaySound(n"Attributes", n"OnFail");
      return false;
    };
    this.OpenDisassembleJunkConfirmation();
  };
  return true;
}

@replaceMethod(BackpackMainGameController)
private final func OpenDisassembleJunkConfirmation() -> Void {
  let items: array<wref<gameItemData>> = AutoDisassembleSystem.Get(this.m_player.GetGame()).Eligible(this.m_player);
  let numberOfItems: Int32 = 0;
  let i: Int32 = 0;
  let data: ref<VendorSellJunkPopupData>;
  while i < ArraySize(items) {
    numberOfItems += items[i].GetQuantity();
    i += 1;
  };
  data = new VendorSellJunkPopupData();
  data.notificationName = n"base\\gameplay\\gui\\widgets\\notifications\\vendor_sell_junk_confirmation.inkwidget";
  data.isBlocking = true;
  data.useCursor = true;
  data.queueName = n"modal_popup";
  data.itemsQuantity = numberOfItems;
  data.actionType = VendorSellJunkActionType.Disassemble;
  this.m_disassembleJunkPopupToken = this.ShowGameNotification(data);
  this.m_disassembleJunkPopupToken.RegisterListener(this, n"OnDisassembleJunkPopupClosed");
  this.m_buttonHintsController.Hide();
}

@replaceMethod(BackpackMainGameController)
protected cb func OnDisassembleJunkPopupClosed(data: ref<inkGameNotificationData>) -> Bool {
  let sellJunkData: ref<VendorSellJunkPopupCloseData> = data as VendorSellJunkPopupCloseData;
  this.m_disassembleJunkPopupToken = null;
  if sellJunkData.confirm {
    AutoDisassembleSystem.Get(this.m_player.GetGame()).Sweep(this.m_player);
    this.PlaySound(n"Item", n"OnDisassemble");
    this.m_TooltipsManager.HideTooltips();
  } else {
    this.PlaySound(n"Button", n"OnPress");
  };
  this.m_buttonHintsController.Show();
  return true;
}
