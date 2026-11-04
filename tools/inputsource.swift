// inputsource — tiny macOS input-source CLI (built by setup.sh into ~/.local/bin).
//
//   inputsource            print the current keyboard input source ID
//   inputsource <ID>       select an *enabled* input source, e.g. com.apple.keylayout.ABC
//
// Used by nvim (lua/config/ime.lua) to drop the Japanese IME back to ABC when
// leaving insert mode. Only Carbon's TIS API, no third-party code. Selecting a
// plain keyboard layout like ABC is reliable this way; selecting a CJK input
// method with TISSelectInputSource has a long-standing macOS race (menu bar
// changes, typing doesn't) — not needed here.
import Carbon

func sourceID(_ src: TISInputSource) -> String {
    guard let p = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return "" }
    return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
}

let args = CommandLine.arguments
if args.count < 2 {
    print(sourceID(TISCopyCurrentKeyboardInputSource().takeRetainedValue()))
    exit(0)
}

let filter = [kTISPropertyInputSourceID as String: args[1]] as CFDictionary
guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
      let src = list.first
else {
    FileHandle.standardError.write("inputsource: not an enabled input source: \(args[1])\n".data(using: .utf8)!)
    exit(1)
}
exit(TISSelectInputSource(src) == noErr ? 0 : 1)
