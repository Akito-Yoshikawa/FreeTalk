//
//  ChatRoomViewController.swift
//  FreeTalk
//
//  Created by 吉川聖斗 on 2022/04/26.
//

import UIKit
import Firebase

class ChatRoomViewController: UIViewController {
    
    public var user: User?
    public var chatRoom: ChatRoom?
    
    private let cellId = "ChatRoomTableViewcellId"
    
    private var messages = [Message]()
    
    private let accessoryHeight: CGFloat = 100
    private let tableViewContentInset: UIEdgeInsets = .init(top: 60, left: 0, bottom: 0, right: 0)
    private let tableViewIndicatorInset: UIEdgeInsets = .init(top: 60, left: 0, bottom: 0, right: 0)
    private var safeAreaBottom: CGFloat {
        self.view.safeAreaInsets.bottom
    }
    
    private lazy var chatInputAccessoryView: ChatInputAccessoryView = {
        let view = ChatInputAccessoryView()
        view.frame = .init(x: 0, y: 0, width: view.frame.width, height: accessoryHeight)
        view.delegate = self
       return view
    }()
    
    @IBOutlet weak var chatRoomTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNotification()
        setupChatRoomTableView()
        fetchMassages()
    }
    
    private func setupNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func setupChatRoomTableView() {
        
        chatRoomTableView.backgroundColor = .green
        chatRoomTableView.delegate = self
        chatRoomTableView.dataSource = self
        chatRoomTableView.register(UINib(nibName: "ChatRoomTableViewCell", bundle: nil), forCellReuseIdentifier: cellId)
        chatRoomTableView.backgroundColor = .rgb(red: 118, green: 140, blue: 180)
        chatRoomTableView.contentInset = tableViewContentInset
        chatRoomTableView.scrollIndicatorInsets = tableViewIndicatorInset
        chatRoomTableView.keyboardDismissMode = .interactive
        chatRoomTableView.transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        chatRoomTableView.rowHeight = UITableView.automaticDimension
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        
        guard let userInfo = notification.userInfo else {
            return
        }
        
        if let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as AnyObject).cgRectValue {
         
            if keyboardFrame.height <= accessoryHeight{
                return
            }
            
            let top = keyboardFrame.height - safeAreaBottom
            var moveY = -(top - chatRoomTableView.contentOffset.y)
            if chatRoomTableView.contentOffset.y != -60 {
                moveY += 60
            }
            let contentInset = UIEdgeInsets(top: top, left: 0, bottom: 0, right: 0)
            
            chatRoomTableView.contentInset = contentInset
            chatRoomTableView.scrollIndicatorInsets = contentInset
            chatRoomTableView.contentOffset = CGPoint(x: 0, y: moveY)
        }
    }

    @objc func keyboardWillHide() {
                
        chatRoomTableView.contentInset = tableViewContentInset
        chatRoomTableView.scrollIndicatorInsets = tableViewIndicatorInset
    }
    
    
    override var inputAccessoryView: UIView? {
        get {
            return chatInputAccessoryView
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }
    private func fetchMassages() {
        guard let chatRoomDocId = chatRoom?.documentId else {
            return
        }
        
        MessageAccessor.sharedManager.getAllMessageSnapshotListener(chatRoomId: chatRoomDocId) { [weak self] (result) in
            guard let self = self else { return }
            
            switch result {
            case .success(let result):
                result?.forEach({ (documentChange) in
                    switch documentChange.type {
                    case .added:
                        let dic = documentChange.document.data()
                        
                        var message = Message(dic: dic)
                        message.partnerUser = self.chatRoom?.partnerUser
                        
                        self.messages.append(message)
                        
                        self.messages.sort { (m1, m2) -> Bool in
                            let m1Date = m1.createdAt.dateValue()
                            let m2Date = m2.createdAt.dateValue()
                            return m1Date > m2Date
                        }
                        
                        self.chatRoomTableView.reloadData()
                        print("message dic: ", dic)
                        
                    case .modified, .removed: break
                        
                    }
                })
                
            case .failure(_):
                self.showSingleBtnAlert(title: "メッセージ情報の取得に失敗しました。")
            }
        }
            
    }
}

extension ChatRoomViewController: ChatInputAccessoryViewDelegate {
    func tappedSendButton(text: String) {
        addMessageToFirestore(text: text)
    }
    
    private func addMessageToFirestore(text: String) {
        guard let chatRoomDocId = chatRoom?.documentId else {
            return
        }
        
        guard let name = user?.username else {
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        
        let messageId = randomString(length: 20)
        
        chatInputAccessoryView.removeText()
        
        let docData = [
            "name": name,
            "createdAt": Timestamp(),
            "uid": uid,
            "message": text
        ] as [String: Any]
        
        // メッセージ情報の保存
        MessageAccessor.sharedManager.setMessage(chatRoomId: chatRoomDocId, messageId: messageId, docData: docData) { (error) in
            if let _ = error {
                return
            }
            
            let latestMessageData = [
                "latestMessageId": messageId
            ]
            
            // ChatRoom直下のlatestMessageにメッセージIDをセットする
            ChatRoomAccessor.sharedManager.setLatestMessage(chatRoomId: chatRoomDocId, latestMessageData: latestMessageData) { (error) in
                if let _ = error {
                    return
                }
                
                print("メッセージ情報の保存に成功しました。")
            }
        }
    }
    
    func randomString(length: Int) -> String {
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let len = UInt32(letters.length)
        
        var randomString = ""
        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        return randomString
    }
}


extension ChatRoomViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        chatRoomTableView.estimatedRowHeight = 20
                
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = chatRoomTableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! ChatRoomTableViewCell
        cell.transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        cell.message = messages[indexPath.row]
        
        return cell
    }
}
