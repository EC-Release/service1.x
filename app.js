
/*const fs = require('fs');
var access = fs.createWriteStream('/var/log/node/svc.log');
process.stdout.write = process.stderr.write = access.write.bind(access);

process.on('uncaughtException', function(err) {
  console.error((err && err.stack) ? err.stack : err);
});*/

var ECService=require('./ec-service');

var phs=new ECService({
    localPort:process.env.RFD_PRT || 7990,
    info: {
	    id: process.env.EC_SVC_ID,
	    url: process.env.EC_SVC_URL,
	    legacy_setting: process.env.EC_SETTING,
	    legacy_adm_tkn: process.env.EC_ADM_TKN,
	    cid: process.env.EC_CID,
	    csc: process.env.EC_CSC
    },
    
    //deprecated
    reporting:{
	vendor: 'nurego',
	//endpoint: process.env.NUREGO_ENDPOINT+'/usages?api_key={apiKey}',
	endpoint: process.env.NUREGO_ENDPOINT+'/usages',
	featureId: process.env.NUREGO_FEATURE_ID,
	usageFeatureId: process.env.NUREGO_USAGE_FEATURE_ID,
	apiKey: process.env.NUREGO_API_KEY,
	tokenURL: process.env.NUREGO_TKN_URL,
	tokenUserName: process.env.NUREGO_TKN_USR,
	tokenPassword: process.env.NUREGO_TKN_PWD,
	tokenInstId: process.env.NUREGO_TKN_INS
    },
    'user-api-auth':{
	type:'zac',
	//clientId: process.env.EC_CID,
	//clientSecret: process.env.EC_CSC,
	//duplicate to EC_SVC_ID    
	//zacServiceId: process.env.ZAC_SERVICE_ID,
	zacUrl: `${process.env.EC_SAC_SLAV_URL}/1.2-b/ec/proc/${process.env.EC_SCRIPT_3}`,
	authUrl: `${process.env.EC_SAC_MSTR_URL}/oauth/token`
    },
    'admin-api-auth':{
	type:'basic',
	id:process.env.ADMIN_USR||'admin',
	token:process.env.ADMIN_TKN||'admin',
	//token:btoa(process.env.ADMIN_TKN||'admin'
    	//token:process.env.EC_ADM_TKN
    },
    //deprecated
    _ssl:{
	key:'./cert/rs-key.pem',
	cert:'./cert/rs-cert.pem'
    },
    groups: {},
    keepAlive: 20000
});

//phs.once('service_listening',()=>{
//});

const exec = require('child_process').exec;
exec(__dirname+'/auth-api', (e, stdout, stderr)=> {
    if (e instanceof Error) {
        console.error(e);
        throw e;
    }
    console.log('stdout ', stdout);
    console.log('stderr ', stderr);
});

//command: DEBUG=rs:gateway node gateway
