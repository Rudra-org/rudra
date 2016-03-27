install:    librudralearner-mock.so
	cp *.so $(RUDRA_HOME)/lib

librudralearner-mock.so:    NativeLearner_Mock.cpp
	g++ -shared -fPIC -g NativeLearner_Mock.cpp -I$(RUDRA_HOME)/include -o librudralearner-mock.so

clean:
	$(RM) *.so

