require('JPEngine').addExtensions(['JPNumber']);

require('UIScreen,MobClick');
defineClass('USHospitalDetailViewController', {
    viewDidLoad: function() {
        self.super().viewDidLoad();

        self.setTitle("医院详情");
        self.setNavigationBackButtonDefault();

        self.addHeader();
        self.updateUI();
        
        self.nameLabel().setNumberOfLines(0);

        var screenWidth = UIScreen.mainScreen().bounds().width;
        var nameHeight = self.nameLabel().text().stringHeightWithFont_width(self.nameLabel().font(), screenWidth - 40);
        self.nameLabel().autoSetDimension_toSize(8, nameHeight);

        MobClick.event("hospital_detail");
    },
});

require('NSString');
defineClass('USInstallmentsPickerView', {}, {
    titleForInstalment: function(instalment) {
        var rate = toOCNumber(instalment.rate() / 10000.0 * 100).stringWithAmountFormat();
        return NSString.stringWithFormat("%@期-服务费%@%%", toOCNumber(instalment.number()), rate);
    },
});

require('HLTool');
defineClass('USHospitalSearchViewController', {
    viewDidLoad: function() {
        self.super().viewDidLoad();

        self.setTitle("选择医院");
        self.setNavigationBackButtonDefault();

        self.setupUI();
        self.addDisplayView();

        HLTool.requestUpdateHosptitalData();
        
        self.searchBar().setClipsToBounds(1);
    },
});

require('UIScrollView,UIColor,UIScreen,UIView,UIImageView,UIButton,UIImage,UIFont,UIActivityIndicatorView');
defineClass('USLoanHintViewController : USViewController', {
    viewDidLoad: function() {
        self.super().viewDidLoad();

        self.setTitle("胡桃钱包");
        self.navigationBar().bottomLine().setHidden(0);
        self.view().setBackgroundColor(UIColor.whiteColor());
        
        var indicatorView = UIActivityIndicatorView.alloc().initWithActivityIndicatorStyle(2);
        indicatorView.startAnimating();
        self.view().addSubview(indicatorView);
        indicatorView.autoCenterInSuperview();

        var sel = self;
        UIImage.imageWithURL_completed("http://walnut-10023356.cos.myqcloud.com/hospital/picture/hosp-pic-b34ae33e-d1ca-4562-9c68-a676612a1e65.png", block('UIImage*', function(image) {
            indicatorView.removeFromSuperview();
            sel.setupContentView();
        }));
    },
    setupContentView: function() {
        var scrollView = UIScrollView.alloc().init();
        scrollView.setBackgroundColor(UIColor.whiteColor());
        self.view().insertSubview_atIndex(scrollView, 0);
        scrollView.autoPinEdgeToSuperviewEdge_withInset(3, 0);
        scrollView.autoPinEdgeToSuperviewEdge_withInset(1, 0);
        scrollView.autoPinEdgeToSuperviewEdge_withInset(4, 0);
        scrollView.autoPinEdgeToSuperviewEdge_withInset(2, 0);

        var imageWidth = UIScreen.mainScreen().bounds().width;
        var imageHeight = imageWidth * 1800 / 1080;

        var contentView = UIView.alloc().init();
        scrollView.addSubview(contentView);
        contentView.autoPinEdgeToSuperviewEdge_withInset(3, 0);
        contentView.autoPinEdgeToSuperviewEdge_withInset(1, 0);
        contentView.autoPinEdgeToSuperviewEdge_withInset(4, 0);
        contentView.autoPinEdgeToSuperviewEdge_withInset(4, 0);
        contentView.autoSetDimension_toSize(7, imageWidth);
        contentView.autoSetDimension_toSize(8, imageHeight + 64 + 67);

        var imageView = UIImageView.alloc().init();
        imageView.setImageWithURL("http://walnut-10023356.cos.myqcloud.com/hospital/picture/hosp-pic-b34ae33e-d1ca-4562-9c68-a676612a1e65.png");
        contentView.addSubview(imageView);
        imageView.autoSetDimension_toSize(8, imageHeight);
        imageView.autoPinEdgeToSuperviewEdge_withInset(3, 64);
        imageView.autoPinEdgeToSuperviewEdge_withInset(1, 0);
        imageView.autoPinEdgeToSuperviewEdge_withInset(2, 0);

        var buttonHeight = 48;

        var bottomButton = UIButton.alloc().init();
        bottomButton.setTitle_forState("前往授信", 0);
        bottomButton.setTitleColor_forState(UIColor.whiteColor(), 0);
        bottomButton.setBackgroundImage_forState(UIImage.imageWithColor(UIColor.colorWithRed_green_blue_alpha(255 / 255, 114 / 255, 187 / 255, 1)), 0);
        bottomButton.setBackgroundImage_forState(UIImage.imageWithColor(UIColor.colorWithRed_green_blue_alpha(235 / 255, 94 / 255, 167 / 255, 1)), 1);
        bottomButton.autoSetDimension_toSize(8, buttonHeight);

        contentView.addSubview(bottomButton);
        bottomButton.autoAlignAxisToSuperviewAxis(9);
        bottomButton.autoConstrainAttribute_toAttribute_ofView_withMultiplier(7, 7, contentView, 280 / 320);
        bottomButton.autoPinEdgeToSuperviewEdge_withInset(4, 20);

        bottomButton.layer().setCornerRadius(buttonHeight / 2);
        bottomButton.layer().setMasksToBounds(YES);
        bottomButton.titleLabel().setFont(UIFont.fontWithName_size("_GBK-", 18));

        bottomButton.addTarget_action_forControlEvents(self, "confirmButtonAction:", 64);
    },
    confirmButtonAction: function(sender) {
        self.dismissViewControllerAnimated_completion(1, null);
    },
});

require('MobClick,USLoanHintViewController');
defineClass('USDataInputViewController', {
    viewDidLoad: function() {
        self.super().viewDidLoad();

        self.setupUserInfoModel();
        self.setupDataSource();
        self.configureTable();
        self.configureViews();

        if (!self.isFromAccount()) {
            self.setEnableScreenEdgePanGesture(0);
            MobClick.event("credit_user_info");

            var viewController = USLoanHintViewController.alloc().init();
            self.presentViewController_animated_completion(viewController, 0, null);
        }
    },
});
