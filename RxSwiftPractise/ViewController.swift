//
//  ViewController.swift
//  RxSwiftPractise
//
//  Created by Sherlock Yao on 11/10/15.
//  Copyright © 2015 Sherlock Yao. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

class ViewController: UIViewController {

    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var repeatPasswordTextField: UITextField!
    @IBOutlet weak var usernameValidationLabel: UILabel!
    @IBOutlet weak var passwordValidationLabel: UILabel!
    @IBOutlet weak var repeatPasswordValidationLabel: UILabel!
    @IBOutlet weak var submitButton: UIButton!
    
    let username = Variable("")
    let password = Variable("")
    let repeatedPassword = Variable("")
    
    var disposeBag = DisposeBag()
    
    let API = GitHubAPI(
        dataScheduler: MainScheduler.sharedInstance,
        URLSession: NSURLSession.sharedSession()
    )
    
    func bindValidationResultToUI(source: Observable<(valid: Bool?, message: String?)>,
        validationErrorLabel: UILabel) {
            source
                .subscribeNext { v in
                    let validationColor: UIColor
                    
                    if let valid = v.valid {
                        validationColor = valid ? UIColor.greenColor() : UIColor.redColor()
                    } else {
                        validationColor = UIColor.grayColor()
                    }
                    
                    validationErrorLabel.textColor = validationColor
                    validationErrorLabel.text = v.message ?? ""
                }
                .addDisposableTo(disposeBag)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        usernameTextField.rx_text <-> username
        passwordTextField.rx_text <-> password
        repeatPasswordTextField.rx_text <-> repeatedPassword
        
        let usernameValidation = username
            .map { [unowned self] username -> Observable<(valid: Bool?, message: String?)> in
                if username.characters.count == 0 {
                    return just((false, nil))
                }
                
                if username.rangeOfCharacterFromSet(NSCharacterSet.alphanumericCharacterSet().invertedSet) != nil {
                    return just((false, "Username can only contain numbers or digits"))
                }
                
                let loadingValue = (valid: nil as Bool?, message: "Checking availabilty ..." as String?)
                
                return self.API.usernameAvailable(username)
                    .map { available in
                        if available {
                            return (true, "Username available")
                        }
                        else {
                            return (false, "Username already taken")
                        }
                    }
                    .startWith(loadingValue)
            }
            .switchLatest()
            .shareReplay(1)
        
        let passwordValidation = password.map { (password) -> (valid: Bool?, message: String?) in
            let numberOfCharacters = password.characters.count
            if numberOfCharacters == 0 {
                return (false, nil)
            }
            if numberOfCharacters < 4 {
                return (false, "Password must be at least 4 characters")
            }
            return (true, "Password acceptable")
        }
        .shareReplay(1)
        
        let repeatPasswordValidation = combineLatest(password, repeatedPassword) { (password, repeatedPassword) -> (valid: Bool?, message: String?) in
            if repeatedPassword.characters.count == 0 {
                return (false, nil)
            }
            if repeatedPassword == password {
                return (true, "Password repeated")
            }
            else {
                return (false, "Password different")
            }
        }
        .shareReplay(1)
        
        let signupEnabled = combineLatest(
            usernameValidation,
            passwordValidation,
            repeatPasswordValidation
            ) { username, password, repeatPassword in
                return (username.valid ?? false) &&
                    (password.valid ?? false) &&
                    (repeatPassword.valid ?? false)
        }
        
        bindValidationResultToUI(
            usernameValidation,
            validationErrorLabel: self.usernameValidationLabel
        )
        
        bindValidationResultToUI(
            passwordValidation,
            validationErrorLabel: self.passwordValidationLabel
        )
        
        bindValidationResultToUI(
            repeatPasswordValidation,
            validationErrorLabel: self.repeatPasswordValidationLabel
        )
        
        signupEnabled
            .subscribeNext { [unowned self] valid  in
                self.submitButton.enabled = valid
                self.submitButton.alpha = valid ? 1.0 : 0.5
            }
            .addDisposableTo(disposeBag)
        
    }

}

infix operator <-> {
}

func <-> <T>(property: ControlProperty<T>, variable: Variable<T>) -> Disposable {
    let bindToUIDisposable = variable
        .bindTo(property)
    let bindToVariable = property
        .subscribe(onNext: { n in
            variable.value = n
            }, onCompleted:  {
                bindToUIDisposable.dispose()
        })
    
    return StableCompositeDisposable.create(bindToUIDisposable, bindToVariable)
}
