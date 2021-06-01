//
//  ExampleCheckoutViewController.swift
//  PaymentSheet Example
//
//  Created by Yuki Tokuhiro on 12/4/20.
//  Copyright © 2020 stripe-ios. All rights reserved.
//

import Foundation
import Stripe
import UIKit

class ExampleCheckoutViewController: UIViewController {
    
    @IBOutlet weak var buyButton: UIButton!
    var paymentSheet: PaymentSheet?
    let backendCheckoutUrl = URL(string: "https://stripe-mobile-payment-sheet.glitch.me/checkout")!  // An example backend endpoint
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        buyButton.addTarget(self, action: #selector(didTapCheckoutButton), for: .touchUpInside)
        buyButton.isEnabled = false
        requestPrepayment()
    }
    
    
    /*
     "publishableKey": "pk_test_51HvTI7Lu5o3P18Zp6t5AgBSkMvWoTtA0nyA7pVYDqpfLkRtWun7qZTYCOHCReprfLM464yaBeF72UFfB7cY9WG4a00ZnDtiC2C",
     "paymentIntent": "pi_1IxCTSLu5o3P18ZpbDlP5gOH_secret_JBUdLr2hMcLtxh9iEbWJ8R5Ou",
     "customer": "cus_JaNDmVMiuIghAE",
     "ephemeralKey": "ek_test_YWNjdF8xSHZUSTdMdTVvM1AxOFpwLGhPWnllWnBBUFg1WXdYeVVkZ29CdmhNVGIwdEp2b3Y_00U8oOuOik"
     */
    func requestPrepayment() {
        // MARK: Fetch the PaymentIntent and Customer information from the backend
        var request = URLRequest(url: backendCheckoutUrl)
        request.httpMethod = "POST"
        let task = URLSession.shared.dataTask(
            with: request,
            completionHandler: { [weak self] (data, response, error) in
                
                // 这应该是 Guard 的正确用法, 在 Guard 里面, 应该有数据的解析工作.
                // 这些被解析出来的数据, 应该在后续的逻辑里面继续被使用.
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data, options: [])
                        as? [String: Any],
                      let customerId = json["customer"] as? String,
                      let customerEphemeralKeySecret = json["ephemeralKey"] as? String,
                      let paymentIntentClientSecret = json["paymentIntent"] as? String,
                      let publishableKey = json["publishableKey"] as? String,
                      let self = self
                else  { return }
                
                
                // 根据网络回调得到各种信息. 这些信息, 都是状态的设置.
                STPAPIClient.shared.publishableKey = publishableKey
                
                var configuration = PaymentSheet.Configuration()
                configuration.merchantDisplayName = "YamiFood." // 设置公司信息.
                configuration.applePay = .init(
                    merchantId: "com.foo.example", merchantCountryCode: "US") // 设置 Apple Pay 的信息.
                configuration.customer = .init(
                    id: customerId, ephemeralKeySecret: customerEphemeralKeySecret) // 设置消费者的信息.
                configuration.returnURL = "payments-example://stripe-redirect" // 设置回调信息.
                 
                // PaymentSheet 生成.
                // 因为 paymentIntentClientSecret 是需要从服务器端交互里面获得的, 所以, PaymentSheet 是一个 Optinal, 只有获得数据之后, 才能生成对应的支付 Sheet.
                self.paymentSheet = PaymentSheet(
                    paymentIntentClientSecret: paymentIntentClientSecret,
                    configuration: configuration)
                
                // 然后才能将 Button 的状态, 设置为可以点击了.
                DispatchQueue.main.async {
                    self.buyButton.isEnabled = true
                }
            })
        task.resume()
    }
    
    @objc
    func didTapCheckoutButton() {
        // 实际上, 调用支付就是 PaymentSheet 的一个 present 方法的调用而已.
        // 为它提供一个宿主环境.
        // 为它提供一个回调函数.
        paymentSheet?.present(from: self) { paymentResult in
            switch paymentResult {
            case .completed:
                self.displayAlert("Your order is confirmed!")
            case .canceled:
                print("Canceled!")
            case .failed(let error):
                print(error)
                self.displayAlert("Payment failed: \n\(error.localizedDescription)")
            }
        }
    }
    
    func displayAlert(_ message: String) {
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
            alertController.dismiss(animated: true) {
                self.navigationController?.popViewController(animated: true)
            }
        }
        alertController.addAction(OKAction)
        present(alertController, animated: true, completion: nil)
    }
}
