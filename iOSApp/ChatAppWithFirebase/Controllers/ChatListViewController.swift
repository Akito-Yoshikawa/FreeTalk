//
//  ChatListViewController.swift
//  ChatAppWithFirebase
//
//  Created by 吉川聖斗 on 2022/04/25.
//

import UIKit
import Firebase
import Nuke

class ChatListViewController: UIViewController {
        
    private let cellId = "cellId"
    private var chatRooms = [ChatRoom]()
    
    private var user: User? {
        didSet {
            navigationItem.title = user?.username
        }
    }
        
    @IBOutlet weak var chatListTableView: UITableView!
        
    override func viewDidLoad() {
        super.viewDidLoad()
         
        setupViews()
        confirmLoggedInUser()
        
        fetchLoginUserInfo()

        fetchChatroomsInfoFromFirestore()
    }
    
    private func fetchChatroomsInfoFromFirestore() {
        Firestore.firestore().collection("chatRooms").addSnapshotListener({ (snapshots, err) in
            if let err = err {
                print("ChatRooms情報の取得に失敗しました。\(err)")
                
                return
            }
            
            snapshots?.documentChanges.forEach({ (documentChange) in
                switch documentChange.type {
                    
                case .added:
                    self.handleAddedDocumentChange(documentChange: documentChange)
                case .modified, .removed: break
                }
            })
            
        })
        
    }
    
    private func handleAddedDocumentChange(documentChange: DocumentChange) {
        
        let dic = documentChange.document.data()
        let chatRoom = ChatRoom.init(dic: dic)
        chatRoom.documentId = documentChange.document.documentID
        
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        
        chatRoom.members.forEach { (memberUid) in
            if memberUid != uid {
                Firestore.firestore().collection("users").document(memberUid).getDocument { (snapshot, err) in
                    if let err = err {
                        print("ユーザーの情報に取得に失敗しました。\(err)")
                        return
                    }
                    
                    guard let dic = snapshot?.data() else {
                        return
                    }
                    
                    let user = User(dic: dic)
                    user.uid = documentChange.document.documentID
                    
                    chatRoom.partnerUser = user
                    self.chatRooms.append(chatRoom)
                    self.chatListTableView.reloadData()
                    
                }
            }
        }
    }
    
    private func confirmLoggedInUser() {
        if Auth.auth().currentUser?.uid == nil {
            let storyboar = UIStoryboard(name: "SignUp", bundle: nil)
            let signUpViewController = storyboar.instantiateViewController(withIdentifier: "SignUpViewController") as! SignUpViewController
            
            signUpViewController.modalPresentationStyle = .fullScreen
            self.present(signUpViewController, animated: true, completion:
            nil)
        }
    }
    
    private func setupViews() {
        chatListTableView.tableFooterView = UIView()
        chatListTableView.delegate = self
        chatListTableView.dataSource = self

        if #available(iOS 15.0, *) {
            
            
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .rgb(red: 39, green: 49, blue: 69)
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        } else {
            navigationController?.navigationBar.barTintColor = .rgb(red: 39, green: 49, blue: 69)
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        }
        
        navigationItem.title = "トーク"

        let rigthBarButton = UIBarButtonItem(title: "新規チャット", style: .plain, target: self, action: #selector(tappedNavRightBarButton))
        
        navigationItem.rightBarButtonItem = rigthBarButton
        navigationItem.rightBarButtonItem?.tintColor = .white

    }
    
    @objc private func tappedNavRightBarButton() {
        let storyboard = UIStoryboard.init(name: "UserList", bundle: nil)
        let userListViewController = storyboard.instantiateViewController(withIdentifier: "UserListViewController")
        let nav = UINavigationController(rootViewController: userListViewController)
        self.present(nav, animated: true, completion: nil)
    }
    
    private func fetchLoginUserInfo() {
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }

        
        Firestore.firestore().collection("users").document(uid).getDocument { (snapshot, err) in

            if let err = err {
                print("ユーザーの情報に取得に失敗しました。\(err)")
                return
            }
 
            guard let snapshot = snapshot,
            let dic = snapshot.data() else {
                return
            }

            let user = User(dic: dic)
            
            self.user = user
        }
    }
    
}


// MARK: - UITableViewDelegate, UITableViewDataSource
extension ChatListViewController: UITableViewDelegate, UITableViewDataSource {
    
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatRooms.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = chatListTableView.dequeueReusableCell(withIdentifier: "cellId", for: indexPath) as! ChatListTableViewCell
        cell.chatroom = chatRooms[indexPath.row]
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard.init(name: "ChatRoom", bundle: nil)
        let chatRoomViewController = storyboard.instantiateViewController(withIdentifier: "ChatRoomViewController") as! ChatRoomViewController
        
        chatRoomViewController.user = user
        chatRoomViewController.chatRoom = chatRooms[indexPath.row]
        
        navigationController?.pushViewController(chatRoomViewController, animated: true)
    }
}

class ChatListTableViewCell: UITableViewCell {

    var chatroom: ChatRoom? {
        didSet {
            if let chatroom = chatroom {
                pertnerLabel.text = chatroom.partnerUser?.username
                userImageView.loadImage(with: chatroom.partnerUser?.profileImageUrl ?? "")
                
                dateLabel.text = dateFormatterForDateLabel(date: chatroom.createdAt.dateValue())
            }
        }
    }
    
    @IBOutlet weak var userImageView: UIImageView!
    @IBOutlet weak var latestMessageLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var pertnerLabel: UILabel!
        
    override func awakeFromNib() {
        super.awakeFromNib()
    
        userImageView.layer.cornerRadius = 30
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    private func dateFormatterForDateLabel(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
        
    }
    
}
