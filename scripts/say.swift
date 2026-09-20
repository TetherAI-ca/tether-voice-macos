import Foundation
// Send a typed command to the running Tether Voice app, exactly like the command box in Settings.
let command = CommandLine.arguments.dropFirst().joined(separator: " ")
guard !command.isEmpty else { FileHandle.standardError.write(Data("usage: say.sh \"command\"\n".utf8)); exit(1) }
DistributedNotificationCenter.default().postNotificationName(Notification.Name("ai.tether.voice.command"), object: command, userInfo: nil, deliverImmediately: true)
