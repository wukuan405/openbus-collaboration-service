A demo Hello tenta demonstrar o uso das facetas específicas dos membros da sessão
de colaboração através da troca de messagens entre cada um dos membros. A criação
da sessão de colaboração é feita pela primeira instância do processo que se conecta
no barramento. Cada um dos membros subsequentes, por sua vez, após conseguir se
conectar no barramento, realizar o login, e tenta acessar a sessão criada pela
primeira instância do processo utilizando um arquivo com o ID da sessão de colaboração.
Se não conseguir após um número de tentativas, falha com uma mensagem de erro.

------------------------------
-------- DEPENDÊNCIAS---------
------------------------------

As dependências de software são fornecidas já compiladas, em conjunto com a demo:

ant-1.8.2.jar
ant-launcher-1.8.2.jar
jacorb-3.1.jar
openbus-sdk-core-2.0.0.0.jar
openbus-sdk-demo-util-2.0.0.0.jar
openbus-sdk-legacy-2.0.0.0.jar
scs-core-1.2.1.1.jar
slf4j-api-1.6.4.jar
slf4j-jdk14-1.6.4.jar

------------------------------
--------- ARGUMENTOS ---------
------------------------------

SessionMember
1) host do barramento
2) porta do barramento
3) nome de entidade

------------------------------
---------- EXECUÇÃO ----------
------------------------------

A demo deve ser executada da seguinte forma:

1) Provider
2) Client

-------------------------------
----------- EXEMPLO -----------
-------------------------------
Supondo que os jars que a demo depende estão em um diretório chamado '/openbus-sdk-java/lib':

2) java -Djava.endorsed.dirs=/openbus-sdk-java/lib/ -cp $(echo lib/*.jar | tr ' ' ':'):openbus-collaboration-demo-java-hello-1.0.0.jar tecgraf.openbus.services.collaboration.v1_0.SessionMember localhost 2089 SessionMember
