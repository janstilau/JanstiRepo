import Foundation

class Recording: Item, Codable {
	override init(name: String, uuid: UUID) {
		super.init(name: name, uuid: uuid)
	}
	
	var fileURL: URL? {
		return store?.fileURL(for: self)
	}
	override func deleted() {
		store?.removeFile(for: self)
		super.deleted()
	}
	
	/*
				 "recording": {
										 "name": "1",
										 "uuid": "D8FF4CA9-1C01-47B8-BB3E-0BE2D0816BD6"
									}
	*/
	enum RecordingKeys: CodingKey { case name, uuid }
	
	required init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: RecordingKeys.self)
		let uuid = try c.decode(UUID.self, forKey: .uuid)
		let name = try c.decode(String.self, forKey: .name)
		super.init(name: name, uuid: uuid)
	}
	
	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: RecordingKeys.self)
		try c.encode(name, forKey: .name)
		try c.encode(uuid, forKey: .uuid)
	}
}
