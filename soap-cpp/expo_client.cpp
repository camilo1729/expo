#include "soapH.h"
#include "expo.nsmap"

const char server[] = "http://localhost:12321";

int main(int argc, char **argv)
{ 
	struct soap soap;
  struct expo__openexperimentResponse open_r;
	struct expo__closeexperimentResponse close_r;
	struct expo__oargridsubasyncResponse oargridsubasync_r;
	struct expo__oargridstatResponse oargridstat_r;
	struct expo__kadeployResponse kadeploy_r;
	struct expo__getkadeployResponse getkadeploy_r;
	struct expo__scriptResponse script_r;
	struct expo__getstdoutResponse getstdout_r;

  soap_init(&soap);

	int sid = 0;
	int gridid = 0;
	int fdbuffer = 0;
	bool todeploy = 1;
	char *queue;

/****************************/
/* open an experiment       */
/****************************/
	printf ("open an experiment\n");
	if (soap_call_expo__openexperiment(&soap, server, "", "yop", open_r)==0)
  {
		sid = open_r._return.sid;
		printf("sid: %d\n", sid);
    printf("reply code: %ld\n", open_r._return.replycode);
    printf("reply message: %s\n",open_r._return.replymsg);
  }
  else soap_print_fault(&soap, stderr);

/****************************/
/* oargridsubasync          */
/****************************/

	if (todeploy) 
		queue="deploy"; 
	else 
		queue="";

	printf ("oargridsubasync gdx:name=testdev:nodes=1 queue=%s walltime=1:0:0 \n",queue);

	if (soap_call_expo__oargridsubasync(&soap, server,"",sid,"gdx:name=testdev:nodes=1",queue,"","1:0:0","","",oargridsubasync_r)==0)
  {
		gridid = oargridsubasync_r._return.gridid;
		printf("gridid: %d\n", gridid);
		printf("result: %s\n", oargridsubasync_r._return.result);
    printf("reply code: %ld\n", oargridsubasync_r._return.replycode);
    printf("reply message: %s\n",oargridsubasync_r._return.replymsg);
  }
  else soap_print_fault(&soap, stderr);

	if (gridid==0) 
	{
		printf("submission error\n");
		exit(1);
	}

/****************************/
/* oargridstat              */
/****************************/

	printf ("oargridstat gridid: %d\n",gridid);
	if (soap_call_expo__oargridstat(&soap, server, "", sid, gridid, oargridstat_r)==0)
  {
		printf ("result: %s\n",  oargridstat_r._return.result);
    printf("reply code: %ld\n",  oargridstat_r._return.replycode);
    printf("reply message: %s\n", oargridstat_r._return.replymsg);
  }
  else soap_print_fault(&soap, stderr);

/****************************/
/*  kadeploy                */
/****************************/

	if (todeploy) 
	{
		printf ("kadeploy: nodeset=testdev, env=debian4all, part=hda6\n");
		if (soap_call_expo__kadeploy(&soap, server,"",sid,"testdev","debian4all","hda6",kadeploy_r)==0)
  	{
    	printf("reply code: %ld\n",  kadeploy_r._return.replycode);
    	printf("reply message: %s\n", kadeploy_r._return.replymsg);
  	}
  	else soap_print_fault(&soap, stderr);
	}

/****************************/
/*  getkadeploy             */
/****************************/
	if (todeploy) 
	{
		printf ("getkadeploy:\n");
		do
		{
			sleep(5);
			if (soap_call_expo__getkadeploy(&soap, server,"",sid,"testdev",getkadeploy_r)==0)
			{
		  	printf("buffer:\n %s\n",  getkadeploy_r._return.buffer);
				printf("state: %s ",  getkadeploy_r._return.state);
		  	printf("progress: %ld ",  getkadeploy_r._return.progress);
				printf("nbnodes: %ld ",  getkadeploy_r._return.nbnodes);
				printf("fdstate: %s ",  getkadeploy_r._return.fdstate);
				printf("reply code: %ld ",  getkadeploy_r._return.replycode);
				printf("reply message: %s\n", getkadeploy_r._return.replymsg);
			}
			else 
			{
				soap_print_fault(&soap, stderr);
				exit(1);
			}
		}
		while (strcmp(getkadeploy_r._return.state,"Completed")!=0 || strcmp(getkadeploy_r._return.fdstate,"close") || strlen(getkadeploy_r._return.buffer)!=0);
	}

/****************************/
/* script                   */
/****************************/
	
	printf ("script: /home/grenoble/orichard/Script/Demo/expo_test.sh yop  nodeset: testdev\n");
	if (soap_call_expo__script(&soap, server,"",sid,"expo_test.sh","/home/grenoble/orichard/Script/Demo/","yop","testdev","",script_r)==0)
  {
		fdbuffer= script_r._return.fdbuffer;
		printf("fdbuffer: %d\n", fdbuffer);
    printf("reply code: %ld\n",  script_r._return.replycode);
    printf("reply message: %s\n", script_r._return.replymsg);
  }
  else soap_print_fault(&soap, stderr);

/****************************/
/* getstdout                */
/****************************/
// TODO
	printf ("getstdout: fdbuffer: %d \n",fdbuffer);
	do
	{
		sleep(3);
		if (soap_call_expo__getstdout(&soap, server,"",sid,fdbuffer,getstdout_r)==0)
		{
		  printf("buffer:\n %s\n",  getstdout_r._return.buffer);
			printf("state: %s ",  getstdout_r._return.state);
		  printf("reply code: %ld ",  getstdout_r._return.replycode);
			printf("reply message: %s\n", getstdout_r._return.replymsg);
		}
		else 
		{
			soap_print_fault(&soap, stderr);
			exit(1);
		}
	}
	while (strcmp(getstdout_r._return.state,"close") || strlen(getstdout_r._return.buffer)!=0);

/****************************/
/* close an experiment      */
/****************************/

	printf ("close an experiment\n");
	if (soap_call_expo__closeexperiment(&soap, server, "", sid, close_r)==0)
  {
    printf("reply code: %ld\n", close_r._return.replycode);
    printf("reply message: %s\n", close_r._return.replymsg);
  }
  else soap_print_fault(&soap, stderr);
                 
	soap_destroy(&soap); // dealloc class instances
  soap_end(&soap); // dealloc deserialized data
  soap_done(&soap); // cleanup and detach soap struct
   
  return 0;
}
                                       
