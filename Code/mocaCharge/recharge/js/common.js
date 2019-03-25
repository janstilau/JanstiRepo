/**
 * Created by ZK on 17/3/22.
 */

// 创建订单编号
function generateOrderID(){
    var formatTime = function(date) {
        var month = date.getMonth() + 1;
        var day = date.getDate();
        var hour = date.getHours();
        var minute = date.getMinutes();
        var second = date.getSeconds();
        return [month, day,hour, minute, second].map(formatNumber).join('') ;
    };
    function formatNumber(n) {
        n = n.toString();
        return n[1] ? n : '0' + n
    }

    var nowDate = new Date();
    var dateStr = formatTime(nowDate);
    var randomNum = Math.random()*1000000000000;
    var oriStr = dateStr + randomNum;
    var orderID = oriStr.substr(0,15);

    return orderID;
}

function getQueryStringArgs() {
    var qs = (location.search.length > 0 ? location.search.substring(1) : ''),
        args = {},
        items = qs.length ? qs.split('&') : [],
        item = null,
        name = null,
        value = null,
        i = 0,
        len = items.length;
    for (i = 0; i < len; i ++) {
        item = items[i].split('=');
        name = decodeURIComponent(item[0]);
        value = decodeURIComponent(item[1]);

        if (name.length) {
            args[name] = value;
        }
    }

    return args;
}
