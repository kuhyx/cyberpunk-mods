// (g) Disassemble into components, automatically: every weapon, piece of
// clothing, junk item and weapon/clothing mod or attachment that lands in
// V's inventory -- except iconics, equipped items, items in a wardrobe
// outfit, favourites and quest items. Grenades, consumables and cyberware
// (including cyberware mods and quickhacks) are never touched. The stash is
// never touched either: only the player's own inventory is scanned.
//
// Runs on pickups outside menus (so buying, crafting and taking items out of
// the stash do not feed the grinder), once after each save load, and from the
// inventory's "Disassemble Junk" button, which now sweeps everything eligible.
module Kuhy.AutoDisassemble

import Kuhy.Common.*

public class AutoDisassembleSystem extends ScriptableSystem {
  // False until the post-load sweep has run: items "added" while the main
  // menu puppet spawns or a save restores the inventory are not pickups.
  private let m_ready: Bool;

  public final func IsReady() -> Bool {
    return this.m_ready;
  }

  public final static func Get(game: GameInstance) -> ref<AutoDisassembleSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"Kuhy.AutoDisassemble.AutoDisassembleSystem") as AutoDisassembleSystem;
  }

  public final func IsEligible(player: ref<PlayerPuppet>, itemData: wref<gameItemData>) -> Bool {
    let itemID: ItemID;
    if !IsDefined(player) || !IsDefined(itemData) {
      return false;
    };
    itemID = itemData.GetID();
    if !this.IsWantedType(itemID) || this.IsSpecialItem(itemData) || RPGManager.IsItemIconic(itemData) {
      return false;
    };
    if RPGManager.IsItemEquipped(player, itemID) || this.IsInWardrobeSet(itemID) {
      return false;
    };
    if UIScriptableSystem.GetInstance(this.GetGameInstance()).IsItemPlayerFavourite(itemID) {
      return false;
    };
    return CraftingSystem.GetInstance(this.GetGameInstance()).CanItemBeDisassembled(player, itemID);
  }

  // Quest items and engine-internal items (fists, underwear, cutscene
  // weapons) that are not real inventory.
  private final func IsSpecialItem(itemData: wref<gameItemData>) -> Bool {
    return itemData.HasTag(n"Quest") || itemData.HasTag(n"HideInUI") || itemData.HasTag(n"IgnoreInventory") || itemData.HasTag(n"Underwear") || itemData.HasTag(n"base_fists");
  }

  // Weapon/clothing mods and attachments report category Invalid at runtime
  // (self-test, 2026-09-30); their Prt_* item type is the reliable signal.
  private final func IsModOrAttachment(itemType: gamedataItemType) -> Bool {
    let name: String = EnumValueToString("gamedataItemType", Cast<Int64>(EnumInt(itemType)));
    return StrBeginsWith(name, "Prt_") && NotEquals(itemType, gamedataItemType.Prt_Fragment) && NotEquals(itemType, gamedataItemType.Prt_Program) && NotEquals(itemType, gamedataItemType.Prt_Capacitor);
  }

  private final func IsWantedType(itemID: ItemID) -> Bool {
    let itemType: gamedataItemType = RPGManager.GetItemType(itemID);
    if this.IsModOrAttachment(itemType) {
      return true;
    };
    switch RPGManager.GetItemCategory(itemID) {
      case gamedataItemCategory.Weapon:
      case gamedataItemCategory.Clothing:
        return true;
      case gamedataItemCategory.General:
        return Equals(itemType, gamedataItemType.Gen_Junk) || Equals(itemType, gamedataItemType.Gen_Jewellery);
      default:
        return false;
    };
  }

  private final func IsInWardrobeSet(itemID: ItemID) -> Bool {
    let sets: array<ref<ClothingSet>> = GameInstance.GetWardrobeSystem(this.GetGameInstance()).GetClothingSets();
    let i: Int32 = 0;
    let j: Int32;
    while i < ArraySize(sets) {
      j = 0;
      while j < ArraySize(sets[i].clothingList) {
        if sets[i].clothingList[j].visualItem == itemID {
          return true;
        };
        j += 1;
      };
      i += 1;
    };
    return false;
  }

  public final func Disassemble(player: ref<PlayerPuppet>, itemData: wref<gameItemData>) -> Bool {
    if !this.IsEligible(player, itemData) {
      return false;
    };
    ItemActionsHelper.DisassembleItem(player, itemData.GetID(), itemData.GetQuantity());
    return true;
  }

  // Every eligible item in the player's inventory (never the stash).
  public final func Eligible(player: ref<PlayerPuppet>) -> array<wref<gameItemData>> {
    let items: array<wref<gameItemData>>;
    let result: array<wref<gameItemData>>;
    let i: Int32 = 0;
    GameInstance.GetTransactionSystem(this.GetGameInstance()).GetItemList(player, items);
    while i < ArraySize(items) {
      if this.IsEligible(player, items[i]) {
        ArrayPush(result, items[i]);
      };
      i += 1;
    };
    return result;
  }

  public final func Sweep(player: ref<PlayerPuppet>) -> Int32 {
    this.m_ready = true;
    let items: array<wref<gameItemData>> = this.Eligible(player);
    let count: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(items) {
      if this.Disassemble(player, items[i]) {
        count += 1;
      };
      i += 1;
    };
    KuhyLog(n"Kuhy.AutoDisassemble", s"sweep disassembled \(count) item stacks");
    return count;
  }

  public final func ScheduleSweep(player: ref<PlayerPuppet>, delay: Float) -> Void {
    let callback: ref<AutoDisassembleSweep> = new AutoDisassembleSweep();
    callback.m_player = player;
    // Game time: it does not advance in the main menu or on a loading
    // screen, so the sweep (and with it m_ready) waits for real gameplay.
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(callback, delay, true);
  }

  // Inventory events arrive mid-transaction; act on the next frame.
  public final func SchedulePickup(player: ref<PlayerPuppet>, itemID: ItemID) -> Void {
    let callback: ref<AutoDisassemblePickup> = new AutoDisassemblePickup();
    callback.m_player = player;
    callback.m_itemID = itemID;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallbackNextFrame(callback);
  }
}

public class AutoDisassembleSweep extends DelayCallback {
  public let m_player: wref<PlayerPuppet>;

  public func Call() -> Void {
    let player: ref<PlayerPuppet> = this.m_player;
    if IsDefined(player) {
      AutoDisassembleSystem.Get(player.GetGame()).Sweep(player);
    };
  }
}

public class AutoDisassemblePickup extends DelayCallback {
  public let m_player: wref<PlayerPuppet>;
  public let m_itemID: ItemID;

  public func Call() -> Void {
    let player: ref<PlayerPuppet> = this.m_player;
    let itemData: wref<gameItemData>;
    if !IsDefined(player) {
      return;
    };
    itemData = GameInstance.GetTransactionSystem(player.GetGame()).GetItemData(player, this.m_itemID);
    if AutoDisassembleSystem.Get(player.GetGame()).Disassemble(player, itemData) {
      KuhyLog(n"Kuhy.AutoDisassemble", s"disassembled pickup \(TDBID.ToStringDEBUG(ItemID.GetTDBID(this.m_itemID)))");
    };
  }
}
