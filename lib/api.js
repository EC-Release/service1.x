/*
 * author: apolo.yasuda@ge.com
 */

'use strict';

//const UTIL = require('util');
//const mime = require('mime');
const ECHealthApi = require("./api/healthApi");
const ECAccountApi = require("./api/accountApi");
const ECReportingApi = require('./api/reportingApi');
const ECUserApi = require('./api/userApi');
const ECSecurityApi = require('./api/securityApi');
const ECStaticApi = require('./api/staticApi');
const ECAuth = require('./auth');
const ECAcc = require('./managers/account-mgr');

const ECCommon = require('./common');

class ECApi extends ECCommon {

    constructor(options){
	super(options);

	this._options.reporting['usage']={
	    data:[]
	}

	this._options.reporting['obj']={}

	/*setInterval(()=>{
	    this._debug(`${new Date()} EC: ${process.env.ZONE} beginning hourly batch reporting.`);
            
	    //temp discarded	
	    return;
	    
	    this.reporting()
		.then((body)=>{
		    this._options.reporting['usage'].data=[];
		    this._options.reporting["obj"]={};
		})
		.catch(err=>{
		    this._debug(`${new Date()} EC: ${process.env.ZONE} reporting error. err: ${err}`);
		});
	}, 1000*60*60);*/
	 
    }

    //nurego
    usageCalc(){
	const _rep=this._options.reporting;

	for (let feature in _rep.obj){

	    let obj={
		"subscription_id": process.env.ZONE,
		"provider": "cloud-foundry",
		"feature_id": feature,
		"amount": _rep.obj[feature],
		"usage_date": (new Date()).getTime(),
		"id": "1"
	    };
	    
	    if (feature=='data_usage')
		obj['unit_of_measure']='Byte';

	   _rep.usage.data.push(obj);

	}
	
	//report only when accumulating too many entries.
	/*if (this._options.reporting.usage.data.length>900) {

	    this.reporting()
		.then((body)=>{
		    this._options.reporting['usage'].data=[];
		})
		.catch(err=>{
		    this._debug(`${new Date()} EC: ${process.env.ZONE} reporting error. err: ${err}`);
		});
	    
	    return;
	}*/
    }

    //nurego
    reporting(){

	return new Promise((reso,reje)=>{

	    this.getReportToken()
		.then(_tkn=>{

		    this.usageCalc();
		    
		    const _rep=this._options.reporting;
		    //let _ep=_rep.endpoint.replace('{apiKey}',_rep.apiKey);
		    let _ep=_rep.endpoint;

		    _rep.usage.count=_rep.usage.data.length;
		    _rep.usage.object='list';
		    
		    let _op={
			headers:{
			    'Content-Type':'application/json',
			    'Authorization':'bearer '+_tkn
			},
			method: 'post',
			url: _ep,
			json:true,
			body:_rep.usage
		    };
		    
		    debugger;

		    this._debug(`${new Date()} EC: ${process.env.ZONE} _op:${JSON.stringify(_op)}`);
		    
		    this._request(_op,(err,res,body)=>{
			debugger;

			if (err||res.statusCode>210){
			    this._debug(`${new Date()} EC: ${process.env.ZONE} body:${JSON.stringify(body)}`);
			    return reje(body);
			}

			this._debug(`${new Date()} EC: ${process.env.ZONE} has been successfully reported in nurego.`);
			debugger;
			return reso(body);
		    });
		})
		.catch(err=>{
		    this._debug(`${new Date()} EC: ${process.env.ZONE} reporting error. err: ${err}`);
		});
	 
	});	
    }

    getReportToken(){
	return new Promise((reso,reje)=>{
	    
	    const _rep=this._options.reporting;

	    let _op={
		headers:{
		    'Content-Type':'application/json'
		},
		method: 'post',
		url: _rep.tokenURL,
		json:true,
		body:{
		    username: _rep.tokenUserName,
		    password: _rep.tokenPassword,
		    "instance_id": _rep.tokenInstId
		}
	    };

	    console.log(_op.body);

	    this._request(_op,(err,res,body)=>{
		if (err||res.statusCode>210){
		    this._debug(`${new Date()} EC: ${process.env.ZONE} body:${JSON.stringify(body)}`);
		    return reje(body);
		}

		this._debug(`${new Date()} EC: ${process.env.ZONE} has successfully fetched the reporting token for nurego.`);

		reso(body.access_token);
	    });
	    
	});
    }
	
    //let _this=this;
    _getRefHash(hsh) {
        return this.cmd('agt', ['-hsh', '-smp'], {
            env: {
                ...process.env,
                EC_PPS: hsh
            }
        }).then((obj)=>{
	    return obj.stdout;
	});
    }

    _getBearerToken(cid,csc,aurl) {
	    
	let _dbg = this._debug,_this=this;	    
	    
        return new Promise((reso, reje) => {

	    this._getRefHash(csc).then((hsh) => {
                //_dbg(`${new Date()} EC: ${options["info"]["id"]} _getRefHash 1 > hsh: ${JSON.stringify(hsh)}`);
                return _this._getRefHash(hsh);
            }).then((hsh) => {

		    let _buf = new Buffer(`${cid}:${hsh}`);

		    let _op = {
			method: 'post',
			url: aurl,
			headers: {
			    'Authorization': 'Basic ' + _buf.toString('base64'),
			    'Content-Type': 'application/x-www-form-urlencoded'
			},
			form: {
				'client_id': cid,
				'grant_type': 'client_credentials'
			    },
			pool: false
		    };

		    _dbg(`${new Date()} auth.js > _oAuthTokenValidation > _op: ${JSON.stringify(_op.headers)}.`);

		    _this._request(_op, (err, res, body) => {
			debugger;
			let _body;

			if (err) {
			    return reje(err);
			}

			try {
			    _body = JSON.parse(body);
			} catch (e) {
			    return reje(e);
			}		    

			if (_body.error) {
			    return reje(_body.error);
			}

			debugger;
			return reso(_body);



		    });	
	  
	    });
  
	
	});
    }
    
    addNewUsage(feature='api_calls',amount=1){

	amount=amount||0;
	
	let op=(this._options.reporting.obj[feature]||0);

	op+=amount;
	
	this._options.reporting.obj[feature]=op;
	//console.log(this._options.reporting.obj);

	//report only when accumulating too many entries.
	/*
	  if (this._options.reporting.usage.data.length>900) {

	    this.reporting()
		.then((body)=>{
		    this._options.reporting['usage'].data=[];
		})
		.catch(err=>{
		    this._debug(`${new Date()} EC: ${process.env.ZONE} reporting error. err: ${err}`);
		});
	    
	    return;
	}
	*/
    }

    getCFOAuthToken(){
	let auth=new ECAuth(this._options,this._debug),
	    usr=process.env.CF_USR,
	    pwd=process.env.CF_PWD,
	    lgn=process.env.CF_LOGIN;

	debugger;
	return auth._oAuthTokenValidation({},
				   {
				       authUrl:lgn,
				       clientId:"cf",
				       clientSecret:""
				   },
				   {
				       grant_type:"password",
				       client_id:"cf",
				       username:usr,
				       password:pwd
				   }).then(([b,a])=>{
				       return b.access_token;
				   });

    }

    setAppSettings(){

	let acc=new ECAcc(this._options),
	    fs = require('fs'),_this=this;
	
	
	//return new Promise((reso, reje) => {

	//this._debug(`${new Date()} EC: ${process.env.ZONE} setAppSettings > acc.GetGroupsDetail():${JSON.stringify(acc.GetGroupsDetail())}`);  


	//});
	_this._getBearerToken(_this._options["info"]["csc"],
			     _this._options["info"]["cid"],
			     _this._options["user-api-auth"]["authUrl"])
		.then((body)=>{
		    _this._options["sacTkn"]=body["access_token"];
		    _this._debug(`${new Date()} EC: ${process.env.ZONE} ECApi > _getBearerToken. bearer token renewed successfully.`);
		})
		.catch(err=>{
		    _this._debug(`${new Date()} EC: ${process.env.ZONE} ECApi > _getBearerToken. bearer token renewal failed. _this._options["info"]: ${JSON.stringify(_this._options["info"])}err: ${err}. programme exiting.`);
		    process.exitCode = 1;
		    process.exit();
		});
	    
	setInterval(()=>{
	    _this._debug(`${new Date()} EC: ${process.env.ZONE} bearer token refreshing.`);
            
	    _this._getBearerToken(_this._options["info"]["csc"],
			         _this._options["info"]["cid"],
			         _this._options["user-api-auth"]["authUrl"])
			.then((body)=>{
			    _this._options["sacTkn"]=body["access_token"];
         		    _this._debug(`${new Date()} EC: ${process.env.ZONE} ECApi > _getBearerToken. scheduled bearer token renewed successfully.`);
			})
			.catch(err=>{
			    _this._debug(`${new Date()} EC: ${process.env.ZONE} ECApi > _getBearerToken. scheduled bearer token renewal failed. err: ${err}`);
			});
	}, 1000*60*18);
	    
	let nb = fs.writeFileSync(`./../svcs/${this._options['info']['id']}.json`, JSON.stringify(acc.GetGroupsDetail(), null, 2), 'utf-8');
	if (nb < 1 ) {
		_this._debug(`${new Date()} EC: ${process.env.ZONE} ECApi > setAppSettings. failed in account serialisation`);
	} else {
	
		_this._debug(`${new Date()} EC: ${process.env.ZONE} setAppSettings > acc.GetGroupsDetail():${JSON.stringify(acc.GetGroupsDetail())}`);  
	}
	//deprecated
	/*let _tk='';
	return this.getCFOAuthToken().then(tk=>{
	    _tk=tk;
	    debugger;
	    return this.getCFEnvVariables(tk);
	}).then(env=>{
	    debugger;
	    let acc=new ECAcc(this._options),
		//ad=JSON.stringify(acc.GetAccount(env.ZONE));
	        ad=JSON.stringify(acc.GetGroupsDetail());

	    debugger;
	    env.EC_SETTINGS=new Buffer(ad).toString('base64');
	    return this.setCFEnvVariables("environment_json",env,_tk);
	});*/
    }

    setCFEnvVariables(_ky,_va, _tkn){
	
	return new Promise((reso,reje)=>{
	    let _api=process.env.CF_API,
		vcap=JSON.parse(process.env.VCAP_APPLICATION),
		_path=`${_api}/v2/apps/${vcap.application_id}`,
		_d={};

	    _d[_ky]=_va;
	    
	    let _op={
		headers:{
		    'Authorization':'bearer '+_tkn
		},
		method: 'put',
		url: _path,
		json:true,
		body:_d
	    };

	    debugger;
	    this._request(_op,(err,res,body)=>{

		if (err||res.statusCode>210){
		    this._debug(`${new Date()} EC: ${process.env.ZONE} body:${JSON.stringify(body)}`);
		    return reje(body);
		}
		
		return reso(body["entity"]["environment_json"]);
	    });
	    
	});
    }

    getCFEnvVariables(_tkn){
	return new Promise((reso,reje)=>{
	    let _api=process.env.CF_API,
		vcap=JSON.parse(process.env.VCAP_APPLICATION),
		_path=`${_api}/v2/apps/${vcap.application_id}/env`,
		_op={
		    headers:{
			'Content-Type':'application/json',
			'Authorization':'bearer '+_tkn
		    },
		    method: 'get',
		    url: _path,
		    json:true
		};
	    debugger;
	    this._request(_op,(err,res,body)=>{

		debugger;
		if (err||res.statusCode>210){
		    this._debug(`${new Date()} EC: ${process.env.ZONE} body:${JSON.stringify(body)}`);
		    return reje(body);
		}
		
		return reso(body["environment_json"]);
	    });
	    
	});
	
    }
        
    hook(req,res){
	
	let _debug=this._debug,
	    _dbg=this._debug, _this=this,
	    _v1="v1",_v1_1="v1.1";

	debugger;
	
	return new Promise((reso,reje)=>{		

	    //get settings at user level
	    /* deprecate for potential security leak
	    if (req.url===("/"+process.env.BASE+"/api/settings")){
		
		let user=new ECUserApi(this._options,this._debug);
		
		if (!user.init(req,res)) {
		    return reje({req:req,res:res,code:501});	    
		}

		switch (req.method.toLowerCase()){
		case "get":
		    return user.getSettings().then(obj=>{
		    	this.addNewUsage();
			return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });

		default:
		    _debug(`${new Date()} EC: ${process.env.ZONE} Unsupported request for ${req.url} (EC API)`);
		    return reso({req:req,res:res,code:401});
		}

		return;
	    }
	    */
	    
	    //token validation
	    if (req.url===("/"+process.env.BASE+"/api/token/validate")||
	         req.url===(`/${_v1}/api/token/validate`)){

		_dbg(`${new Date()} EC: ${_this._options['info']['id']} /api/token/validate called.`);
		
		let user=new ECUserApi(_this._options,_dbg);
		
		//_dbg(`${new Date()} EC: ${_this._options['info']['id']} user: ${user} _this._options: ${JSON.stringify(_this._options)}`);
		//return reso({});
		//try {
		if (!user.init(req,res)) {
		    //_dbg(`${new Date()} EC: ${_this._options['info']['id']} user.init failed.`);
		    return reje('user.init failed.');	    
		}

		//_dbg(`${new Date()} EC: ${_this._options['info']['id']} user.init called.`);
		//return reso({});
		    
		switch (req.method.toLowerCase()){
		case "post":
		    return user.tokenValidate().then(obj=>{
		    	this.addNewUsage();
			return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });
		}

		return reje('unsupported method');
	    }

	    //get the list of active gateways
	    if (req.url===("/"+process.env.BASE+"/api/gateways")||
	         req.url===(`/${_v1}/api/gateways`)){

		let user=new ECUserApi(_this._options,_dbg);
		
		if (!user.init(req,res)) {
		    return reje('failed init user');	    
		}

		switch (req.method.toLowerCase()){
		case "post":
		    return user.xchangeGatewayList().then(obj=>{
		    	this.addNewUsage();
			return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });
		}

		return;
	    }

	    //for user to retrieve the public key
	    if (req.url===("/"+process.env.BASE+"/api/pubkey")||
	         req.url===(`/${_v1}/api/pubkey`)){

		let user=new ECUserApi(this._options,this._debug);
		
		if (!user.init(req,res)) {
		    return reje('failed user.init');	    
		}

		switch (req.method.toLowerCase()){
		case "get":
		    return user.getPublicKey().then(obj=>{
		    	this.addNewUsage();
			return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });
		}

		return;
	    }

	    //health APIs
	    if (req.url===("/"+process.env.BASE+"/health/check")||
	         req.url===(`/${_v1}/health/check`)){
	
		let health=new ECHealthApi(this._options,this._debug);
		
		if (!health.init(req,res)) {
		    return reje({req:req,res:res,code:501});	    
		}

		return health.checkStatus().then(obj=>{
		    this.addNewUsage();
		    return reso(obj);
		}).catch((err)=>{
		    return reje(err);
		});
	    }
		
	    if (req.url===("/"+process.env.BASE+"/health/memory")||
	         req.url===(`/${_v1}/health/memory`)){
		
		let health=new ECHealthApi(this._options,this._debug);
		    
		//_debug(`${new Date()} EC: ${_this._options['info']['id']} checkMemory called`);
		    
		if (!health.init(req,res)) {
		    return reje({req:req,res:res,code:501});	    
		}

		//_debug(`${new Date()} EC: ${_this._options['info']['id']} health.init called`); 
		return health.checkMemory().then(obj=>{
		    //_debug(`${new Date()} EC: ${_this._options['info']['id']} checkMemory passed`); 
		
		    this.addNewUsage();
		    return reso(obj);
		}).catch((err)=>{
		    return reje(err);
		});
	    }

	    //reporting APIs
	    if (req.url.indexOf("/"+process.env.BASE+"/reports/usage")===0||
	         req.url.indexOf(`/${_v1}/reports/usage`)===0){

		let report=new ECReportingApi(this._options,this._debug);
		    
		if (!report.init(req,res)) {
		    return reje({req:req,res:res,code:501});	    
		}

		switch (req.method.toLowerCase()){
		case "post":
		    return report.reportUsage().then(obj=>{
			if (obj.code==200){
			    console.log("obj.data.lastUsage",obj.data.lastUsage);
			    this.addNewUsage('data_usage',obj.data.lastUsage);
			}
			return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });
		    
		case "get":
		    return report.getUnreportedUsage().then(obj=>{
			this.addNewUsage();
			return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });
		}

	    }

	    //security APIs
	    if (req.url.indexOf("/"+process.env.BASE+"/certs/csr")===0||
	         req.url.indexOf(`/${_v1}/certs/csr`)===0){

		let security=new ECSecurityApi(this._options,this._debug);
		
		if (!security.init(req,res)) {
		    return reje({req:req,res:res,code:501});	    
		}

		switch (req.method.toLowerCase()){

		case "post":
		    return security.submitCSR().then(obj=>{
			this.addNewUsage();
			return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });
		    
		case "get":
		    return security.getCSR().then(obj=>{
			this.addNewUsage();
			return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });
		}

	    }

	    //security APIs
	    if (req.url.indexOf("/"+process.env.BASE+"/certs/service")===0||
	         req.url.indexOf(`/${_v1}/certs/service`)===0){

		let security=new ECSecurityApi(this._options,this._debug);
		
		if (!security.init(req,res)) {
		    return reje({req:req,res:res,code:501});	    
		}
		
		switch (req.method.toLowerCase()){

		case "get":
		    return security.getPublicKey().then(obj=>{
			this.addNewUsage();
			return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });
		}
	    }

	    
	    //account query APIs
	    if (req.url.indexOf("/"+process.env.BASE+"/admin/accounts/validate")===0||
	         req.url.indexOf(`/${_v1}/admin/accounts/validate`)===0){
		
		let acc=new ECAccountApi(this._options,this._debug);
		
		if (!acc.init(req,res)) {
		    return reje({req:req,res:res,code:501});	    
		}

		debugger;
		switch (req.method.toLowerCase()){

		case "get":
		    return acc.validateAccount().then((obj)=>{
			this.addNewUsage();
			 return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });
		}
	    }
	    
	    //admin APIs
	    if (req.url.indexOf("/"+process.env.BASE+"/admin/accounts/list")===0||
	         req.url.indexOf(`/${_v1}/admin/accounts/list`)===0||
         	   req.url.indexOf(`/${_v1_1}/admin/accounts/list`)===0){
		
		let acc=new ECAccountApi(this._options,this._debug);
		
		if (!acc.init(req,res)) {
		    return reje({req:req,res:res,code:501});	    
		}

		debugger;
		switch (req.method.toLowerCase()){

		case "get":
		    return acc.getAccountList().then((obj)=>{
			this.addNewUsage();
			 return reso(obj);
		    }).catch((err)=>{
			return reje(err);
		    });
		}
	    }
	    
	    //admin APIs
	    if (req.url.indexOf("/"+process.env.BASE+"/admin/accounts/")===0||
	         req.url.indexOf(`/${_v1}/admin/accounts/`)===0||
         	   req.url.indexOf(`/${_v1_1}/admin/accounts/`)===0){
		
		let acc=new ECAccountApi(this._options,this._debug),
		    _dbg=this._debug;
		
		if (!acc.init(req,res)) {
		    return reje("acc init failed");	    
		}
		
		debugger;
		switch (req.method.toLowerCase()){

		case "put":
		    return acc.updateAccount().then((obj)=>{
			this.addNewUsage();
			return this.setAppSettings().then(ent=>{
		 	    return reso({code:201,data:ent});
			});
			
		    }).catch((err)=>{
			return reje(err);
		    });
		    
	    	case "post":
		    return acc.createAccount().then((obj)=>{
			debugger;
			_dbg(`${new Date()} EC: ${process.env.ZONE} ${req.url} > createAccount > obj ${obj}`);
			this.addNewUsage();
			    			
			//_dbg(`${new Date()} EC: ${process.env.ZONE} ${req.url} > createAccount > addNewUsage > obj ${obj}`);
			return this.setAppSettings().then((ent)=>{
				//_dbg(`${new Date()} EC: ${process.env.ZONE} ${req.url} > createAccount > addNewUsage > setAppSettings > ent: ${ent}`);
			
				return reso({code:201,data:ent});
			});
		    }).catch((err)=>{
			_dbg(`${new Date()} EC: ${process.env.ZONE} ${req.url} > createAccount > err:${err}`);
			
			return reje(err);
		    });
		    
		case "get":
		    return acc.getAccount().then((obj)=>{
			this.addNewUsage();
			 
			return reso({code:201,data:obj});
		    }).catch((err)=>{
			return reje(err);
		    });
		    
		case "delete":
		    return acc.deleteAccount().then((obj)=>{
			this.addNewUsage();
			return this.setAppSettings().then(ent=>{
			    return reso({code:201,data:ent});
			});
		    }).catch((err)=>{
			return reje(err);
		    });
		}
	    }

	    
	    //public revision info
	    if ((req.url.indexOf("/"+process.env.BASE+"/info/")===0||
	         req.url.indexOf(`/${_v1}/info/`)===0)&&
		req.method.toLowerCase()==="get"){

		let sfile=new ECStaticApi(_this._options,_this._debug);
		
		if (!sfile.init(req,res)) {
		    return reje({code:501,data:'static api failed whilst initialising.'});	    
		}

		return sfile.getRevision().then((obj)=>{
		    return reso(obj);
		}).catch((err)=>{
		    return reje(err);
		});
	    }

	    //static resources
	    if ((req.url.indexOf("/"+process.env.BASE+"/index/")===0||
	         req.url.indexOf(`/${_v1}/index/`)===0)&&
		req.method.toLowerCase()==="get"){

		let sfile=new ECStaticApi(_this._options,_this._debug);
		
		if (!sfile.init(req,res)) {
		    return reje({code:501,data:'static data failed in initialising.'});	    
		}

		return sfile.getUI().then((obj)=>{
		    return reso(obj);
		}).catch((err)=>{
		    return reje(err);
		});

	    }
	    
	    //static default
	    if (req.url==="/"&&
		req.method.toLowerCase()==="get"){
		res.writeHead(301,{Location: "/ui/"});
		return reso({req:req,res:res,code:301});
	    }

	    //static ui
	    if (req.url.indexOf("/ui/")===0&&
		req.method.toLowerCase()==="get"){
	
		let sfile=new ECStaticApi(_this._options,_this._debug);
		
		if (!sfile.init(req,res)) {
		    return reje({req:req,res:res,code:501,data:'static data failed in initialising'});	    
		}

		return sfile.getAsset().then((obj)=>{
		    return reso(obj);
		}).catch((err)=>{
		    return reje(err);
		});
	    }

	    _debug(`${new Date()} EC: ${process.env.ZONE} received request for ${req.url} but service failed to pick up.`);
	    return reje({code:404,err:"service failed to pick up"});
	});
    };

}

module.exports=ECApi;
