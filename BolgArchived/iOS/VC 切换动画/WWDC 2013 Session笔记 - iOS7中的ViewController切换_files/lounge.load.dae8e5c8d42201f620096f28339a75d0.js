!function(){"use strict";var a=window.document,b={STYLES:"https://c.disquscdn.com/next/embed/styles/lounge.d49f53e192b9080ef8880a7c9b24f1c3.css",RTL_STYLES:"https://c.disquscdn.com/next/embed/styles/lounge_rtl.cab57597e8a76dfb98345cdfb296ec5b.css","lounge/main":"https://c.disquscdn.com/next/embed/lounge.bundle.53ce1bd42cd56ff599219e9d5c200428.js","discovery/main":"https://c.disquscdn.com/next/embed/discovery.bundle.daedd146972fc7d8dffd9be34c404865.js","remote/config":"https://disqus.com/next/config.js","common/vendor_extensions/highlight":"https://c.disquscdn.com/next/embed/highlight.6fbf348532f299e045c254c49c4dbedf.js"};window.require={baseUrl:"https://c.disquscdn.com/next/current/embed",paths:["lounge/main","discovery/main","remote/config","common/vendor_extensions/highlight"].reduce(function(a,c){return a[c]=b[c].slice(0,-3),a},{})};var c=a.createElement("script");c.onload=function(){require(["common/main"],function(a){a.init("lounge",b)})},c.src="https://c.disquscdn.com/next/embed/common.bundle.18932c85febf9520158697cdc31f08ae.js",a.body.appendChild(c)}();