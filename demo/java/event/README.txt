A demo "event" procura demosntrar o uso da funcionalidade de canal de evento de
uma sessão de colaboração. Neste demo teremos 2 atores principais:
 - publicador: responsável por criar uma sessão de colaboração e gerar eventos 
               no canal desta mesma sessão gerada
 - consumidor: responsável por consumir os eventos enviados pelo canal 

------------------------------
-------- DEPENDÊNCIAS---------
------------------------------

As dependências de software são fornecidas já compiladas, em conjunto com a demo:

ant-1.8.2.jar
ant-launcher-1.8.2.jar
jacorb-3.3.jar
openbus-sdk-core-2.0.0.1.jar
openbus-sdk-demo-util-2.0.0.1.jar
openbus-sdk-legacy-2.0.0.1.jar
scs-core-1.2.1.1.jar
slf4j-api-1.6.4.jar
slf4j-jdk14-1.6.4.jar

------------------------------
--------- ARGUMENTOS ---------
------------------------------

Servidor
1) host do barramento
2) porta do barramento
3) nome de entidade
4) senha (opcional - se não for fornecida, será utilizado o nome de entidade)

Cliente
1) host do barramento
2) porta do barramento
3) nome de entidade
4) senha (opcional - se não for fornecida, será usado o nome de entidade)


------------------------------
---------- EXECUÇÃO ----------
------------------------------

A demo deve ser executada na seguinte ordem:

1) Produtor de eventos (publisher)
2) Consumidor de eventos (subscriber)


-------------------------------
----------- EXEMPLO -----------
-------------------------------
Supondo que os jars que a demo depende estão em um diretório chamado '/openbus-sdk-java/lib':

1) java -Djava.endorsed.dirs=/openbus-sdk-java/lib/ -cp $(echo lib/*.jar | tr ' ' ':'):openbus-collaboration-demo-java-event-1.0.0.jar tecgraf.collaboration.demo.ClockPublisher localhost 2089 ClockPublisher

2) java -Djava.endorsed.dirs=/openbus-sdk-java/lib/ -cp $(echo lib/*.jar | tr ' ' ':'):openbus-collaboration-demo-java-event-1.0.0.jar tecgraf.collaboration.demo.ClockSubscriber localhost 2089 ClockSubscriber
