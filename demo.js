//-*- Mode: Javascript; coding: utf-8; c-basic-offset: 2; -*-

//======================================================================
// form data read/write

//--------------------------------------------------------------
//-- nod = getid(id)
function getid(id) {
    return document.getElementById(id);
}

//-- nod = getname(name)
function getname(name) {
    return document.getElementsByName(name)[0];
}

//--------------------------------------------------------------
// val = valGet(nod_or_id_or_name)
function valGet(id) {
    var nod = id;
    if (typeof(nod) == 'string') {
	nod = getid(id);
	if (nod==null) {
	    nod = getname(id);
	}
    }
    if (nod==null) {
	throw("valGet(): no node for id="+id);
	return null;
    }
    var ttag = nod.tagName.toLowerCase();

    if (ttag=="input" || ttag=="select" || ttag=="textarea") {
	var ttype = nod.getAttribute('type');
	if (ttype==null) { ttype=ttag; }
	ttype = ttype.toLowerCase();
	if (ttype=="checkbox")    { return nod.checked; }
	else if (ttype=="select") { return nod.options[nod.selectedIndex].value; }
	else { return nod.value; }
    }
    return nod.innerHTML;
}

//--------------------------------------------------------------
// undef = valSet(nod_or_id_or_name,val)
function valSet(id,val) {
    var nod = id;
    if (typeof(nod) == 'string') {
	nod = getid(id);
	if (nod==null) {
	    nod = getname(id);
	}
    }
    if (nod==null) {
	throw("valSet(): no node for id="+id+", val="+val);
	return null;
    }
    if (val==null) {
	val = "";
    }
    var ttag = nod.tagName.toLowerCase();
    if (ttag=="input" || ttag=="select") {
	var ttype = nod.getAttribute('type');
	if (ttype==null) { ttype = ttag; }
	ttype = ttype.toLowerCase();
	if (ttype=="checkbox")    { nod.checked = Boolean(val); }
	else if (ttype=="select") {
	    for (opti in nod.options) {
		if (nod.options[opti].value == val) {
		    nod.selectedIndex = opti;
		    break;
		}
	    }
	}
	else { nod.value = String(val); }
    } else {
	nod.innerHTML = String(val);
    }
}

//======================================================================
// generic XMLHttpRequest stuff

//-- encstr = formString({param:val,...})
function formString(params) {
    var form = [];
    for (var p in params) {
	if (params[p] == null) { continue; }
	form.push(p+'='+encodeURIComponent(params[p]));
    }
    return form.join('&');
}

//-- uristr = getURI(base,{param:val,...})
function getURI(base,params) {
    return base + '?' + formString(params);
}

//-- undef = httpGet(uri,onReadyCallback)
//  + onReadyCallback = function(req) { ... }
function httpGet(uri,onReadyCallback) {
    var get_uri = uri;
    var req = new XMLHttpRequest();
    req.open("GET",get_uri,true);
    req.onreadystatechange=function(){onReadyCallback(req)};
    req.send(null);
}

//======================================================================
// cab request

var cab_url_base = '/query';

function cabQuery() {
    //-- common parameters
    var params = {
	"a" : valGet('a'),
	"fmt" : valGet('fmt'),
	"clean" : Number(valGet('clean')),
    };
    //-- flags
    if (valGet('pretty')) {
	params['pretty'] = "1";
	params['raw']    = "1";
    }
    if (!valGet('exlex_enabled')) {
	params['exlex_enabled']  = "0";
	params['static_enabled'] = "0";
    }

    //-- query
    var q = valGet('q');
    var qp = 'q';
    if (valGet('tokenize')) {
	qp = 'q';
    } else {
	qp = 'qd';
    }
    params[qp] = q;

    //-- options
    try {
	var opts_s = valGet('qo');
	var opts = JSON.parse(opts_s);
	if (opts != null) {
	    for (var o in opts) {
		if (opts[o] == null) {
		    delete params[o];
		} else {
		    params[o] = opts[o];
		}
	    }
	}
    }
    catch (err) {
	clog("cabQuery(): error parsing user options: " + err.descroption);
    }

    //-- guts
    var caburi = getURI(cab_url_base,params);
    var cablink = getid('cabLink');
    cablink.href      = caburi;
    cablink.innerHTML = caburi;
    valSet('cabData', 'Querying ' + caburi);
    httpGet(caburi,
	    function(req){ if (req.readyState==4) { valSet('cabData',req.responseText); } });

    //-- traffic-light query
    cabTrafficQuery(q, 'btn_trf_cabq');

    //-- return false to disable form submission
    return false;
}

//======================================================================
// CAB auto-query ("traffic lights")

function cabTrafficQuery(w,spanid) {
    var nod = getid(spanid);
    nod.style.backgroundColor = '#c0c0c0'; //-- unknown: white
    nod.title = nod.title.replace(/safe|unsafe|unrecognized|unknown/g, 'unknown');
    if (w.search(/\s/) != -1) { return; } //-- word with spaces: ignore it
    httpGet(getURI(cab_url_base,
		   {"qd":JSON.stringify({"text":w}),
		    "fmt":"json",
		    "a":"default.msafe",
		    "exlex_enabled":0,
		    "clean":0,
		   }),
	    function(req){ cabTrafficReady(w,spanid,req) });
}

var cab_autobg_red    = '#ff0000';
var cab_autobg_yellow = '#ffff00';
var cab_autobg_green  = '#00ff00';
function cabTrafficReady (w,spanid,req) {
    if (req.readyState!=4) { return; }
    if (req.status>=400) {
	clog('cabAutoReady('+w+'): HTTP Error: '+req.status);
	return;
    }
    var rsp = JSON.parse(req.responseText);
    var tok = rsp.body[0].tokens[0];
    var nod = getid(spanid);
    var xlit_id    = (tok.text == tok.xlit.latin1Text);
    var has_morph  = (tok.morph!=null && tok.morph.length>0);
    var has_mlatin = (tok.mlatin!=null && tok.mlatin.length>0);
    if (w.search(/\s/) != -1) {
	; //-- do nothing
    }
    else if (xlit_id && Boolean(tok.msafe) && has_morph) {
	nod.style.backgroundColor = cab_autobg_green;
	nod.title = nod.title.replace(/safe|unsafe|unrecognized|unknown/g, 'safe');
    }
    else if (xlit_id && (has_morph || has_mlatin)) {
	nod.style.backgroundColor = cab_autobg_yellow;
	nod.title = nod.title.replace(/safe|unsafe|unrecognized|unknown/g, 'unsafe');
    }
    else {
	nod.style.backgroundColor = cab_autobg_red;
	nod.title = nod.title.replace(/safe|unsafe|unrecognized|unknown/g, 'unrecognized');
    }
}

//======================================================================
// debugging

function clog(msg) {
    if (typeof(console)!='undefined' && console!=null) {
	//-- javascript log
	console.log(msg);
    }
    //-- local log
    var lnod = document.getElementById('logData');
    if (lnod != null) {
	valSet(lnod,valGet(lnod)+msg+'\n');
    }
}

//======================================================================
// query parsing

// map = parseQuery(queryStr)
function parseQuery(qs) {
    var qm = {};
    if (qs.substr(0,1)=='?') { qs=qs.substr(1); } //-- strip leading "?"
    var ql = qs.split("&");
    for (var i=0; i<ql.length; i++) {
	var kv = ql[i].split("="); 
	qm[decodeURIComponent(kv[0])] = decodeURIComponent(kv[1].replace(/\+/g,' '));
    }
    return qm;
}


//======================================================================
// CAB demo stuff

function cabDemoInit() {
    var nod = getid('cabLink');
    cab_url_base = 'http://' + window.location.host + '/query';
    nod.href = cab_url_base;
    nod.innerHTML = cab_url_base;

    //-- initialize
    var qm = parseQuery(window.location.search);
    var qmkeys = ["q","a","fmt","pretty","clean","exlex_enabled","tokenize","qo"];
    for (var i=0; i<qmkeys.length; i++) {
	if (qm[qmkeys[i]] != null) { valSet(qmkeys[i], qm[qmkeys[i]]); }
    }
    if (String(valGet('q')) != "") { cabQuery(); }
}
