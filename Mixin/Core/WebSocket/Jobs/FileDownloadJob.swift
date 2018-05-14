import Foundation
import Bugsnag

class FileDownloadJob: AttachmentDownloadJob {

    override lazy var fileName: String = "\(message.messageId).\(FileManager.default.pathExtension(mimeType: message.mediaMimeType ?? ""))"
    override lazy var fileUrl = MixinFile.url(ofChatDirectory: .files, filename: fileName)
    
    init(message: Message) {
        super.init(messageId: message.messageId)
        super.message = message
    }

    static func fileJobId(messageId: String) -> String {
        return "file-download-\(messageId)"
    }

    override func getJobId() -> String {
        return FileDownloadJob.fileJobId(messageId: message.messageId)
    }

}
