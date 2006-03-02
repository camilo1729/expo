GSOAP=soapcpp2
SOAPH=stdsoap2.h
SOAPCPP=stdsoap2.cpp
CPP=g++
LIBS=
COFLAGS=-O2
CWFLAGS=-Wall
CIFLAGS=-I../..
CMFLAGS=
CFLAGS= $(CWFLAGS) $(COFLAGS) $(CIFLAGS) $(CMFLAGS)
all: expo 

expo: expo.h expo_client.cpp 
	$(GSOAP) -C -L -t -x -w expo.h
	$(CPP) $(CFLAGS) -o expo_client expo_client.cpp soapC.cpp soapClient.cpp $(SOAPCPP) $(LIBS)

clean:
		rm -f *.o soapH.h soapStub.h soapC.cpp soapC.c soapClient.cpp soapClient.c soapServer.cpp soapServer.c soap*Proxy.h
distclean:
		rm -f *.o *.wsdl *.xsd *.xml *.nsmap *.log soapH.h soapStub.h soapC.cpp soapC.c soapClient.cpp soapClient.c soapServer.cpp soapServer.c soap*Proxy.h expo_client
