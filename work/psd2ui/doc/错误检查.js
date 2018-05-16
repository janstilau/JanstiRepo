labelFilter={
size:{require:true,tp:"int"},
color:{require:true,tp:"color"},
bold:{require:false,tp:"bool"},
w:{require:false,tp:"int"},
align:{require:false,tp:"enum",opts:["left","middle","right"]},
rich:{require:false,tp:"int"},
d:{require:false,tp:"int"},
outline:{require:false,tp:"color"},
f:{require:false,tp:"str"},
};
var Timer={
  data:{},
  start:function(key){
    Timer.data[key]=new Date();
  },
  stop:function(key){
    var time=Timer.data[key];
    if(time)
    Timer.data[key]=new Date()-time;
  },
  getTime:function(key){
    return Timer.data[key];
  }
};
function inArray(needle,array){    
    if(typeof needle=="string"||typeof needle=="number"){    
        for(var i in array){    
            if(needle===array[i]){    
              
                return true;    
            }    
        }    
        return false;    
    }    
}  
 function main() {
    if ( app.documents.length <= 0 ) {
                alert("没有打开的文档");
                return "cancel";
        }
	 
    /*
    alert(checkName("sdfsdssf-_123"));
    info = checkInvalidProp("size=sdf@color=ss@bold=3".split("@"),0,clone(labelFilter));
    alert(info);
    return;*/
    var doc = app.activeDocument
      Timer.start("tm");
    info =  checkLayers("",doc,0);
    
    Timer.stop("tm");
    //alert("time:"+Timer.getTime("tm")+"len:" );
    if(info != "")
    {
        alert("检查结束,发现错误,请将错误信息保存到文件");
          var f = new File("d:/file.txt");
        f.open("w");
        f.write(info);
        f.saveDlg("保存检查日志");
	f.execute();
         }
  else 
        alert("检查结束,未发现错误");
}
function getProp(str,field)
{
        strs = str.split("@");
        for(var i=0;i<strs.length;i++)
        {
                if(strs[i].indexOf (field+"=", 0) == 0)
                {
                    return strs[i].substr((field+"=").length);
                 }
        }
        return "";
}
function setProp(str,field,val)
{
        strs = str.split("@");
        var found = false;
        for(var i=0;i<strs.length;i++)
        {
                if(strs[i].indexOf (field+"=", 0) == 0)
                {
                    strs[i] = field+"="+val;
                    found = true;
                    break;
                 }
        }
        if(!found)
            strs.push(field+"="+val);
        return strs.join("@");
}
function checkName(name)
{
    if(name.indexOf(".psd")>0)
    return "";
    if(name.indexOf("#")>0)
        name = name.substr(name.indexOf("#")+1);
    if(name.length == 0)
        return "名称含不能为空:"+name+"\n";
    var m =  name.match(/[^a-z_0-9\.\-_@=]/g);
    if(m != null)
        return "名称含有非法字符:"+name+","+m+"\n";
    return "";        
 }
function clone(obj) {
      var o;
      if (typeof obj == "object") {
          if (obj === null) {
              o = null;
          } else {
              if (obj instanceof Array) {
                  o = [];
                  for (var i = 0, len = obj.length; i < len; i++) {
                     o.push(clone(obj[i]));
                 }
             } else {
                 o = {};
                 for (var j in obj) {
                     o[j] = clone(obj[j]);
                 }
             }
         }
     } else {
         o = obj;
     }
     return o;
 }
function checkInvalidProp(strs,offset,filter)
{
    info = "";
     for(var i=offset;i<strs.length;i++)
     {
         var s = strs[i];
        if(s == "")
        continue;
         var s2 = s.split("=");
          if(s2.length != 2)
            info += "参数非法:"+s+"\n";
         else
         {
             var f = s2[0];
             var v = s2[1];
             if(filter[f])
             {
                 switch(filter[f].tp)
                 {
                        case "int":
                            var iv = parseInt(v);
                            if(isNaN(iv) || iv == 0)
                                    info += "参数类型应该为整型:"+s+"\n";
                        break;
                        case "color":
                             var m =  v.match(/[^0-9a-f]/ig);
                            if(v.length != 6 || m != null)
                                info += "参数类型应该为颜色值:"+s+"\n";
                            break;
                        case "bool":
                            if( v != "1" && v != "true")
                                info += "参数类型应该为1或true:"+s+"\n";
                            break;    
                         case "enum":
                            if(!inArray(v,filter[f].opts))
                                info += "参数类型应该为以下值:"+filter[f].opts.join("|")+",当前为:"+s+"\n";
                         break;
                  }
                 filter[f].checked = true;
              }
             else
             {
                 info += "多余的参数:"+s+"\n";
              }
         }
     }
    for(var k in filter)
    {
        if(filter[k].require && !filter[k].checked)
             info += "参数为必选参数:"+k+"\n";
    }
    return info;
 }

function checkLabel(l,prepath,depth)
{
    var strs = l.name.split("@");
    info = checkName(strs[0]);
   
     var t = l.textItem;
     if(t.contents != "")
      {
            var sz = getProp(l.name,"size");
            
            var cursz =Math.round(t.size.value);
            if(sz != cursz+"")
            { 
                    if(sz != "")
                        info +="文字大小不匹配，原始:"+sz+",实际大小:"+cursz+",已自动修正\n";
                    l.name = setProp(l.name,"size",cursz);
                    
                //alert(l.name+",kind:"+l.kind);
             }
             var color = getProp(l.name,"color");
          var curcolor =t.color.rgb.hexValue.toLowerCase();
        if(color!= curcolor)
        { 
                if(color != "")
                    info +=" 颜色值不匹配，原始:"+color+",实际大小:"+curcolor+",已自动修正\n";
                l.name = setProp(l.name,"color",curcolor);
                
            //alert(l.name+",kind:"+l.kind);
         }
         }
     else
     {
         l.name = setProp(l.name,"size",20);
          l.name = setProp(l.name,"color","ffffff");
    }      
    strs = l.name.split("@");
    
    var offset = 1;
    if(strs[1] == "label")
        offset = 2;
    // if(l.name.indexOf("juexing")==0)
      //  alert("ss");
     info +=  checkInvalidProp(strs,offset,clone(labelFilter));
     return info;
 }
function checkButton(prepath,l,depth)
{
    var info = checkChildren(prepath,l,depth)
    return info;
}
function getRealName(n)
{
        if(n.indexOf("#")>=0)
            n = n.substr(n.indexOf("#")+1);
        if(n.indexOf("@")>0)
            n = n.substr(0,n.indexOf("@"));
        return n;    
 }
function checkScrollview(prepath,obj,depth)
{
    var len = obj.artLayers.length;
    var preserve={};
    var curname = getRealName(obj.name);
    for( var i = 0; i < len; i++) {
        
        var c= obj.artLayers[i];
        var n = getRealName(c.name);
        
        if(n.indexOf(curname+".") == 0)
        {
            var suffix = n.substr((curname+".").length);
            switch(suffix)
            {
                    case "cont":
                        break;
                        
             }
        }
       
        
            
    }
    return checkChildren(prepath,obj,depth);
}
function checkList(prepath,l,depth)
{
    return checkChildren(prepath,l,depth);
}
function checkTabcont(prepath,l,depth)
{
    return checkChildren(prepath,l,depth);
}
function checkTextarea(prepath,l,depth)
{
    return checkChildren(prepath,l,depth);
}
function checkObj(l)
{
     if(l.kind == LayerKind.TEXT)
    {
        return checkLabel(l);
       
     }
     
     return checkImg(l);
 }
function checkImg(l)
{
   return checkName(l.name); 
 }   
function checkByName(l)
{
      
  return "";
 }
function checkDepth(prepath,obj,depth)
{
        if(depth>5)
            return "层数大于5："+prepath+"/"+obj.name+"\r\n";
        
           
            
            var len = obj.layerSets.length;
            for( var i = 0; i < len; i++) {
                info += checkDepth(prepath+"/"+obj.layerSets[i].name,obj.layerSets[i],depth+1);
            }        
    return info;
}


function checkChildren(prepath,obj,depth)
{
        var info = "";
         var len = obj.artLayers.length;
    
            for( var i = 0; i < len; i++) {
                
                var l = obj.artLayers[i];
                
               var v = checkObj(l);
               if(v != "")
               {
		changeColor(l);
		info += prepath+"/"+l.name+"有错误:\n"+v;
               } 
               //else
		//clearColor(l)
            }
           
            
            len = obj.layerSets.length;
            for( var i = 0; i < len; i++) {
                info += checkLayers(prepath+"/"+obj.layerSets[i].name,obj.layerSets[i],depth+1);
            }        
    return info;
}
function setColor(layer,color)
{
	app.activeDocument.activeLayer = layer;
	var idsetd = charIDToTypeID( "setd" );
    var desc12 = new ActionDescriptor();
    var idnull = charIDToTypeID( "null" );
        var ref6 = new ActionReference();
        var idLyr = charIDToTypeID( "Lyr " );
        var idOrdn = charIDToTypeID( "Ordn" );
        var idTrgt = charIDToTypeID( "Trgt" );
        ref6.putEnumerated( idLyr, idOrdn, idTrgt );
    desc12.putReference( idnull, ref6 );
    var idT = charIDToTypeID( "T   " );
        var desc13 = new ActionDescriptor();
        var idClr = charIDToTypeID( "Clr " );
        var idClr = charIDToTypeID( "Clr " );
        var idVlt = charIDToTypeID( color );
        desc13.putEnumerated( idClr, idClr, idVlt );
    var idLyr = charIDToTypeID( "Lyr " );
    desc12.putObject( idT, idLyr, desc13 );
	executeAction( idsetd, desc12, DialogModes.NO );
}
function changeColor(obj)
{
	//if(fixed)
	//	setColor(obj,"Grn ");	
	//else
		setColor(obj,"Vlt ");
}

function clearColor(obj)
{
	setColor(obj,"Vlt ");
	 
}
function checkLayers(prepath,obj,depth)
{
    if(depth>5)
    {
	changeColor(obj,false);
	return "层数大于5："+prepath+"/"+obj.name+"\r\n";
    }
    var info = checkName(obj.name);

    var strs = obj.name.split("@");
     
    
  
     switch(strs[1])
     {
         case "button":
            return checkButton(prepath,obj,depth);
         break; 
         case "scrollview":
            return checkScrollview(prepath,obj,depth);
         break;
         case "list":
            return checkList(prepath,obj,depth);
         break;
         case "tabcont":
            return checkTabcont(prepath,obj,depth);
         break;
         case "tabcont.cont":
            return checkChildren (prepath, obj,depth);
         break;
         case "tab":
            return checkChildren (prepath, obj,depth);
         break;
         case "textarea":
            return checkTextarea(prepath,obj,depth);
         break;
         case "ignore":
         return checkDepth(prepath, obj,depth);
         case "togglegroup":
         return checkChildren(prepath, obj,depth);
         break;
         default:
            if( obj.name.indexOf(".psd")<0 &&strs.length>1&& strs[1].indexOf("=")<0)
            {
		changeColor(obj,false);
		return "未知的类型:"+strs[1]+"\n";
	    }
           return checkChildren (prepath, obj,depth);
         break;
      }
    
    
    
 
    return info;
 }

main(); 