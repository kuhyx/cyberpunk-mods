// Shared logging for the Kuhy mods. ModLog (red4ext/logs, readable by
// scripts/check_logs.sh) comes from Codeware; if RED4ext did not load,
// Codeware is absent and logging degrades to the vanilla no-op FTLog so the
// mods still compile and run.
module Kuhy.Common

@if(ModuleExists("Codeware"))
public static func KuhyLog(mod: CName, text: String) -> Void {
  ModLog(mod, text);
}

@if(!ModuleExists("Codeware"))
public static func KuhyLog(mod: CName, text: String) -> Void {
  FTLog(NameToString(mod) + ": " + text);
}
