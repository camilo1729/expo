//gsoap expo service name:        expo
//gsoap expo service style:       rpc
//gsoap expo service encoding:    encoded
//gsoap expo service namespace:   http://grid5000.fr/expo
//gsoap expo service location:    http://grid5000.fr/expo

//gsoap expo schema namespace:    http://grid5000.fr/expo
//gsoap ruby schema namespace:    http://www.ruby-lang.org/xmlns/ruby/type/custom

typedef char *xsd__string;
typedef long xsd__int;

// common reply class

// without specific return
class ruby__reply
{  
	public:
  xsd__int replycode;
  xsd__string replymsg;
};

// with short result (string)
class ruby__result
{  
	public:
	xsd__string result;
  xsd__int replycode;
  xsd__string replymsg;
};

// openexperiement

class ruby__sid
{  
	public:
	xsd__int sid;
  xsd__int replycode;
  xsd__string replymsg;
};

struct expo__openexperimentResponse { ruby__sid _return;};

int expo__openexperiment(xsd__string name,
												struct expo__openexperimentResponse &r);

// closeexperiment

struct expo__closeexperimentResponse { ruby__reply _return;};

int expo__closeexperiment(xsd__int sid,
												struct expo__closeexperimentResponse &r);

//oargridsub','sid','desc','queue','program','walltime','dir','date')
// TODO
// oargridsub

class ruby__oargridsubasync
{  
	public:
	xsd__int gridid;
	xsd__string result;
  xsd__int replycode;
  xsd__string replymsg;
};


struct expo__oargridsubasyncResponse { ruby__oargridsubasync _return;};

int expo__oargridsubasync(xsd__int sid,
											xsd__string desc,
											xsd__string queue,
											xsd__string program,
											xsd__string walltime,
											xsd__string dir,
											xsd__string date,
											struct expo__oargridsubasyncResponse &r); 

// oargridstat
struct expo__oargridstatResponse { ruby__result _return;};

int expo__oargridstat(xsd__int sid,
										xsd__int gridid,
										struct expo__oargridstatResponse &r); 

// kadeploy
struct expo__kadeployResponse { ruby__reply _return;};

int expo__kadeploy(xsd__int sid,
									xsd__string nodeset,
									xsd__string env,
									xsd__string part,
									struct expo__kadeployResponse &r);

// getkadeploy

class ruby__getkadeploy
{
	public:
	xsd__string state;
	xsd__int progress;
	xsd__int nbnodes;
	xsd__string fdstate;
	xsd__string buffer;
  xsd__int replycode;
  xsd__string replymsg;

};

struct expo__getkadeployResponse { ruby__getkadeploy _return;};

int expo__getkadeploy(xsd__int sid,
										xsd__string nodeset,
										struct expo__getkadeployResponse &r); 


// script

class ruby__script
{  
	public:
	xsd__int fdbuffer;
  xsd__int replycode;
  xsd__string replymsg;
};

struct expo__scriptResponse { ruby__script _return;};

int expo__script(xsd__int sid,
								xsd__string program,
								xsd__string dir,
								xsd__string args,
								xsd__string nodeset,
								xsd__string opt, 		
								struct expo__scriptResponse &r); 
// NOTE 1 "nodeset" indique la frontale pour le lancement du script 
// NOTE 2 "opt" si opt=nodefilelist se traduira par l'option --nodefilelist fichier_nodeset dans la ligne de commande [A CONFIRMER]


// getstdout

class ruby__getstdout
{  
	public:
	xsd__string state;
	xsd__string buffer;
  xsd__int replycode;
  xsd__string replymsg;
};

struct expo__getstdoutResponse { ruby__getstdout _return;};

int expo__getstdout(xsd__int sid,
										xsd__int fd,
										struct expo__getstdoutResponse &r); 



