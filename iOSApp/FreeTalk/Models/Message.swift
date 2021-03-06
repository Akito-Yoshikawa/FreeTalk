//
//  Message.swift
//  FreeTalk
//
//  Created by 吉川聖斗 on 2022/05/12.
//

import Foundation
import Firebase
import FirebaseFirestoreSwift

struct Message {
    let name: String
    let message: String
    let uid: String
    let createdAt: Timestamp

    var partnerUser: User?

    init(dic: [String: Any]) {
        self.name = dic["name"] as? String ?? ""
        self.message = dic["message"] as? String ?? ""
        self.uid = dic["uid"] as? String ?? ""
        
        self.createdAt = dic["createdAt"] as? Timestamp ?? Timestamp()
    }
    
    static func allMessagesTargetCollectionRef(_ chatRoomId: String) -> CollectionReference {
        return Firestore.firestore().collection("chatRooms").document(chatRoomId).collection("messages")
    }
    
    static func targetCollectionRef(_ chatRoomId: String, _ latestMessageId: String) -> DocumentReference {
        return Firestore.firestore().collection("chatRooms").document(chatRoomId).collection("messages").document(latestMessageId)
    }    
}
