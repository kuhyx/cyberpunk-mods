// (b) Load the newest save -- the main menu's "Continue" -- the first time the
// main menu appears in a game process. Quitting to the menu later is left
// alone, so the one-shot flag lives in a Codeware service (one per process)
// rather than on the menu controller (recreated every time the menu opens).
module Kuhy.AutoContinue

public class AutoContinueService extends ScriptableService {
  private let m_fired: Bool;

  public final func Claim() -> Bool {
    if this.m_fired {
      return false;
    };
    this.m_fired = true;
    return true;
  }

  public final static func Get() -> ref<AutoContinueService> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"Kuhy.AutoContinue.AutoContinueService") as AutoContinueService;
  }
}

// Metadata for save index 0 is what the vanilla Continue path needs to pick
// LoadModdedSave vs LoadLastCheckpoint, so fire only once it has arrived.
@wrapMethod(SingleplayerMenuGameController)
protected cb func OnSaveMetadataReady(info: ref<SaveMetadataInfo>) -> Bool {
  let result: Bool = wrappedMethod(info);
  if info.saveIndex == 0 && info.isValid && this.m_savesCount > 0 {
    let service: ref<AutoContinueService> = AutoContinueService.Get();
    if IsDefined(service) && service.Claim() {
      ModLog(n"Kuhy.AutoContinue", s"loading newest save (modded=\(this.m_isModded))");
      if this.m_isModded {
        this.LoadModdedSave(0);
      } else {
        this.GetSystemRequestsHandler().LoadLastCheckpoint(false);
      };
    };
  };
  return result;
}
