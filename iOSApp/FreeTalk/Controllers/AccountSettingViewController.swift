//
//  AccountSettingViewController.swift
//  FreeTalk
//
//  Created by 吉川聖斗 on 2022/05/25.
//

import Foundation
import UIKit
import PKHUD

class AccountSettingViewController: UIViewController, UINavigationControllerDelegate {
        
    private var isUserIdUnique = false {
        // 値の監視
        didSet {
            if isUserIdUnique {
                // アラート表示
                self.showSingleBtnAlert(title: "利用可能です。") {
                    // ボタンタイトル利用可能変更
                    self.userIdUniqueCheckButton.setTitle("利用可能です", for: .normal)
                    // ボタン選択させない
                    self.userIdUniqueCheckButton.isEnabled = false
                }
            } else {
                // ボタンタイトル利用可能変更
                self.userIdUniqueCheckButton.setTitle("利用可能か確認", for: .normal)
                // ボタン選択させない
                self.userIdUniqueCheckButton.isEnabled = true
            }
        }
    }
    
    private var currentUser: User? {
        didSet {
            if let currentUser = currentUser {
                
                NukeAccessore.sharedManager.loadImage(thumnaillString: currentUser.profileImageUrl) { [weak self]
                    imageResponse in
                    
                    HUD.hide()

                    guard let self = self,
                          let imageResponse = imageResponse else {
                              return
                          }
                    
                        self.profileImageButton.setImage(imageResponse.image, for: .normal)
                        self.profileImageButton.setTitle("", for: .normal)
                    
                        self.modifeldProfileImage = false

                }
                self.userNameTextField.text = currentUser.username
                self.userIdTextField.text = currentUser.userID

                self.userIntroductionTextView.text = currentUser.selfIntroduction
            }
        }
    }
        
    /// プロフィール画像を一度でも変更したか？
    private var modifeldProfileImage = false

    // 最大UserName文字数
    private let maxUserNameLength = UserAccessor.sharedManager.maxUserNameLength
    
    // 最大UserID文字数
    private let maxUserIdLength = UserAccessor.sharedManager.maxUserIdLength
    
    @IBOutlet weak var profileImageButton: UIButton!
        
    @IBOutlet weak var userNameTextField: UITextField!
        
    @IBOutlet weak var userIdTextField: UITextField!
            
    @IBOutlet weak var userIdUniqueCheckButton: UIButton!
    
    @IBOutlet weak var userIntroductionTextView: UITextView!

    @IBOutlet weak var accountUpdateButton: UIButton!
            
    override func viewDidLoad() {
        super.viewDidLoad()

        setUpViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                
        // currentUser.uidとUserAccessor.sharedManager.currentUser?.uidが違う場合(ログアウトして変更された)再度取得を行う
        if self.currentUser?.uid != UserAccessor.sharedManager.currentUser?.uid {

            HUD.show(.progress)
            // user取得
            self.setUserAndGetUser()
        }
    }
    
    private func setUpViews() {
        self.profileImageButton.layer.cornerRadius = 85
        self.profileImageButton.layer.borderWidth = 1
        self.profileImageButton.layer.borderColor = UIColor.rgb(red: 240, green: 240, blue: 240).cgColor

        self.profileImageButton.setTitle("", for: .normal)
        self.profileImageButton.imageView?.contentMode = .scaleAspectFill
        self.profileImageButton.clipsToBounds = true

        userNameTextField.delegate = self
        userIdTextField.delegate = self
        
        navigationController?.changeNavigationBarBackGroundColor()

        navigationItem.title = "アカウント設定"
    }
    
    private func setUserAndGetUser() {
        // CurrentUserセット、CurrentUserを取得
        UserAccessor.sharedManager.setCurrentUser() { [weak self] (result) in
            guard let self = self else { return }
            if !result {
                print("CurrentUserのSetに失敗しました。")
            }

            self.currentUser = UserAccessor.sharedManager.returnCurrentUser()
        }
    }
    
    private func uploadProfileImage(uploadImage: Data, completion: @escaping (String?) -> Void) {
        ProfileImageAccessor.sharedManager.uploadProfileImage(uploadImage) { [weak self]
            (urlString) in
            
            guard let urlString = urlString else {
                self?.showSingleBtnAlert(title: "アカウントの設定に失敗しました。")
                completion(nil)
                return
            }

            completion(urlString)
        }
    }
    
    private func updateUserToFirestore(docData: [String: Any]) {
        guard let uid = UserAccessor.sharedManager.currentUid else {
            self.showSingleBtnAlert(title: "アカウントの設定に失敗しました。")
            HUD.hide()
            return
        }
                    
        UserAccessor.sharedManager.setUserData(memberUid: uid, docData: docData, isMerge: true) { [weak self]
            (error) in

            guard let self = self else { return }

            if let _ = error {
                self.showSingleBtnAlert(title: "アカウントの設定に失敗しました。")
                HUD.hide()
                return
            }

            self.showSingleBtnAlert(title: "アカウントの設定を変更しました。")
            print("アカウントの設定に成功しました")
        }
    }
    
    @IBAction func tappedProfileBtn(_ sender: Any) {
        
        // TODO: 削除するかセットするか選ばせたい

        let imagePickerController = UIImagePickerController()
        
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true

        self.present(imagePickerController, animated: true, completion: nil)
    }
    
    @IBAction func tappedUserIdUniqueCheck(_ sender: Any) {
        guard let userId = self.userIdTextField.text,
                  !userId.isEmpty else {
                      self.showSingleBtnAlert(title: "ユーザーIDを入力してください。")
                      return
              }

        // 自分が使用しているユーザーIDかどうかチェック
        if userId == UserAccessor.sharedManager.currentUser?.userID {
            // ユニークであるため登録おっけ
            self.isUserIdUnique = true
            return
        }
        
        // 入力されたuserIDがユニークかどうかチェック
        UserAccessor.sharedManager.checkUniqueUserId(userId: userId) {
            (isUnique) in
            
            if isUnique {
                // ユニークであるため登録おっけ
                self.isUserIdUnique = true
            } else {
                self.showSingleBtnAlert(title: "既に利用されています。") {
                    // ユニークではないため登録NG
                    self.isUserIdUnique = false
                }
            }
        }
    }
    
    @IBAction func tappedAccountUpdate(_ sender: Any) {
        guard let userNameStr = self.userNameTextField.text,
              let userId = self.userIdTextField.text,
              let userIntroduction = self.userIntroductionTextView.text else {
                  return
              }
        
        // ユーザー名があるかチェック
        if userNameStr.isEmpty {
            // ユーザー名がない場合はエラーアラート表示
            self.showSingleBtnAlert(title: "ユーザー名は必須項目です。")
            return
        }
        
        var docData = [String: Any]()

        // ユーザー名追加
        docData["username"] = userNameStr

        // ユーザーID追加、使用可能か確認して、あったら追加
        if !userId.isEmpty {

            // 自分が使用しているユーザーIDかどうかチェック
            if userId != UserAccessor.sharedManager.currentUser?.userID {
                if !isUserIdUnique {
                    self.showSingleBtnAlert(title: "ユーザーIDが利用可能か確認ボタンを押してください。")
                    return
                }
                docData["userID"] = userId
            }
        }
        // 自己紹介文あったら追加
        if !userIntroduction.isEmpty {
            docData["selfIntroduction"] = userIntroduction
        }
                        
        HUD.show(.progress)
                        
        // userimage画像更新、デフォルトアイコンを設定
        guard let profileImageUrl = profileImageButton.imageView?.image,
              let uploadImage = profileImageUrl.jpegData(compressionQuality: 0.3) else {
              
                  let defaultImage = ProfileImageAccessor.sharedManager.defaultImage
                  guard let uploadDefaultImage = defaultImage?.jpegData(compressionQuality: 0.3) else {
                      return
                  }
                  
                  // プロフィール画像のアップロード
                  self.uploadProfileImage(uploadImage: uploadDefaultImage) {
                      [weak self] (urlString) in

                      // プロフィール画像URL追加
                      docData["profileImageUrl"] = urlString
                      
                      // Userの更新
                      self?.updateUserToFirestore(docData: docData)
                      
                      // 表示更新
                      self?.setUserAndGetUser()
                                            
                      HUD.hide()
                  }
                  return
              }
        
        
        // プロフィール画像が変更されているかどうか
        // 変更していない場合はアップロードしない
        if !modifeldProfileImage {
            
            // Userの更新
            self.updateUserToFirestore(docData: docData)
            // 表示更新
            self.setUserAndGetUser()
            HUD.hide()
            return
        }
        
        // プロフィール画像のアップロード
        self.uploadProfileImage(uploadImage: uploadImage) {
            [weak self] (urlString) in

            // プロフィール画像URL追加
            docData["profileImageUrl"] = urlString
            
            // Userの更新
            self?.updateUserToFirestore(docData: docData)
            
            // 表示更新
            self?.setUserAndGetUser()
            
            HUD.hide()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

extension AccountSettingViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let editImage = info[.editedImage] as? UIImage {
            profileImageButton.setImage(editImage.withRenderingMode(.alwaysOriginal), for: .normal)
        } else if let originalImage = info[.originalImage] as? UIImage {
            profileImageButton.setImage(originalImage.withRenderingMode(.alwaysOriginal), for: .normal)
        }
        
        profileImageButton.setTitle("", for: .normal)
        
        modifeldProfileImage = true
        
        dismiss(animated: true, completion: nil)
    }
}

extension AccountSettingViewController: UITextFieldDelegate {
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        if let userName = userNameTextField.text {
            if userName.count > maxUserNameLength {
                userNameTextField.text = String(userName.prefix(maxUserNameLength))
            }
        }
        
        if let userId = userIdTextField.text {
            if userId.count > maxUserIdLength {
                userIdTextField.text = String(userId.prefix(maxUserIdLength))
            }
            
            self.isUserIdUnique = false
        }
    }
}
