function connectWebViewJavascriptBridge(callback) {
  if (window.WebViewJavascriptBridge) {
    callback(WebViewJavascriptBridge)
  } else {
    document.addEventListener('WebViewJavascriptBridgeReady', function() {
      callback(WebViewJavascriptBridge)
    }, false)
  }
}
connectWebViewJavascriptBridge(function(bridge) {
  bridge.init()

  $(function () {
    var baseUrl = 'http://api.himoca.com/moca/DailyDraw/';
    // var baseUrl = 'http://app.himoca.com:8080/moca/DailyDraw/';
    var loginUid;
    var ua = navigator.userAgent;
    var isIos = ua.indexOf('Mac') > -1 && ua.indexOf('Mobile') > -1;
    var isAndroid = ua.indexOf('Mozilla/5.0') > -1 && ua.indexOf('Android ') > -1 && ua.indexOf('AppleWebKit') > -1 && ua.indexOf('Chrome') === -1;
    var isIosWebView = ua.indexOf('Mac') > -1 && ua.indexOf('Mobile') > -1 && ua.indexOf('Safari') === -1;
    var $startBtn = $('.start-btn');
    var $disk = $('.award-items');
    var initialAngle = 0;
    var payAmount;
    var payNumber;
    var payProd;
    var _aliWapPay = false;

    var prizes = {
      prize0: {
        angleShift: 0,
        name: '1天VIP'
      },
      prize1: {
        angleShift: 45,
        name: '3天VIP'
      },
      prize2: {
        angleShift: 45 * 2,
        name: '5天VIP'
      },
      prize3: {
        angleShift: 45 * 3,
        name: '2朵花'
      },
      prize4: {
        angleShift: 45 * 4,
        name: '10朵花'
      },
      prize5: {
        angleShift: 45 * 5,
        name: '50朵花'
      },
      prize6: {
        angleShift: 45 * 6,
        name: '99朵花'
      },
      prize7: {
        angleShift: 45 * 7,
        name: '520朵花'
      }
    };

    // 获取信息中的参数 flower_count
    // 最终设置花为 flower_count*3 + 得到的花*3

    // 获取用户信息
    bridge.callHandler('UserInfo', {}, function(d) {
      // alert(d);
      console.log(d);

      if(typeof d === 'string') {
        var d = JSON.parse(d);
      }

      if (d.userInfo) {
          loginUid = d.userInfo.uid;
          d.extraInfo && !!d.extraInfo.aliWapPay && (_aliWapPay = true);
      }
      else {
          loginUid = d.uid;
      }

      checkStates();
      $startBtn.on('click', function () {
        draw();
      })
    });

    // loginUid = 2253302;
    function checkStates() {
      bridge.callHandler('CallInterface', {'url': baseUrl + 'check', 'params': {}}, function (d) {
        console.log(d);
        //   alert(JSON.stringify(d));
        if(typeof d === 'string') {
          var d = JSON.parse(d);
        }
        // alert(d.succes)
        if(d.succes) {
          // alert(JSON.stringify(d.result))
          d.result.buy.indexOf(1) > -1 ? $('#btn-recharge-1').prop('disabled', true) : $('#btn-recharge-1').prop('disabled', false);
          d.result.buy.indexOf(10) > -1 ? $('#btn-recharge-10').prop('disabled', true) : $('#btn-recharge-10').prop('disabled', false);
          d.result.buy.indexOf(88) > -1 ? $('#btn-recharge-88').prop('disabled', true) : $('#btn-recharge-88').prop('disabled', false);
          d.result.buy.indexOf(188) > -1 ? $('#btn-recharge-188').prop('disabled', true) : $('#btn-recharge-188').prop('disabled', false);
          d.result.buy.indexOf(288) > -1 ? $('#btn-recharge-288').prop('disabled', true) : $('#btn-recharge-288').prop('disabled', false);

          if(d.result.draw) {
            $('#left-draw-number').removeClass('hide');
            $('#left-draw-number .number-text').html(d.result.draw);
            $startBtn.prop('disabled', false);
          } else {
            $startBtn.prop('disabled', true);
          }

        }
      })

    }


    // 打开支付选项弹窗
    $('.btn-recharge').on('click', function () {
      payAmount = $(this).data('amount');
      payNumber = $(this).data('number');
      payProd = $(this).data('prod');
      $('.dialog').addClass('show');
      $('.dialog-overlay').addClass('show');
    })

    // 关闭支付选项弹窗
    $('.dialog-overlay').on('click', function () {
      $('.dialog').removeClass('show');
      $('.dialog-overlay').removeClass('show');
    })

    $('.pay-btn').on('click', function () {
      // console.log($(this).data('pay'), itemIndex);

        var payType = $(this).data('pay');

        // if chose alipay in iOS, wap pay rather than app pay
        if (payType === 2 && isIos && _aliWapPay) {

            sessionStorage['uid'] = loginUid;
            sessionStorage['total_fee'] = parseInt(payAmount)*100;
            sessionStorage['flower_num'] = parseInt(payNumber);
            sessionStorage['prod'] = payProd;

            location.href = 'pay.html';
            return;
        }

      bridge.callHandler('BuyFlower', {'type':payType, params:{'prod': payProd}, 'amount': payAmount, 'number': payNumber}, function(d) {
        // 支付成功会返回 success: true
        console.log(d);
        if(typeof d === 'boolean') {
          if(d) {
            location.reload();
          }
        }
        if(d.succes) {
          location.reload();
        }
      })
    })

    /* 点击转盘按钮 */

    function draw() {
      if($(this).prop('disabled')) return false;
      $(this).prop('disabled', true);

      bridge.callHandler('CallInterface', {'url': baseUrl + 'luck', 'params': {}}, function (d) {
        console.log(d);
        if(typeof d === 'string') {
          var d = JSON.parse(d);
        }
        // alert(JSON.stringify(d))
        if(d.succes) {
          prizeType = parseInt(d.result.prize);
          totalAngle = initialAngle + 3600 + prizes['prize'+prizeType]['angleShift'] + Math.floor(Math.random() * 11 - 5);
          $disk.css({transform: 'rotate(' + totalAngle + 'deg)'})
            .on('transitionend webkitTransitionEnd', function() {
              alert('恭喜你！抽中' + prizes['prize'+prizeType].name)
              location.reload();
            });
        }
      })

    }
  })
});
