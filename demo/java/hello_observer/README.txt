A demo Hello Observer tenta demonstrar o uso das facetas específicas dos membros da
sessão de colaboração através da troca de messagens entre cada um dos membros da sessão.
A criação da sessão e o monitoramento da entrada e saída de membros da sessão é feita
pelo observador. O observador só funciona após conseguir se conectar no barramento,
realizar o login, encontrar a oferta do serviço de colaboração, e criar uma sessão
no serviço de colaboração. Caso o login seja perdido, sua callback de login inválido
tenta refazer esse processo por um número máximo de tentativas.

Cada um dos membros da sessão, por sua vez, após conseguir se conectar no barramento,
realizar o login, e encontrar a oferta do serviço de colaboração, tenta acessar a
sessão criada pelo observador da sessão utilizando um arquivo com o ID da sessão de
colaboração. Se não conseguir após um número de tentativas, falha com uma mensagem
de erro.

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

SessionObserver
1) host do barramento
2) porta do barramento
3) nome de entidade
4) senha (opcional - se não for fornecida, será utilizado o nome de entidade)
5) arquivo onde será gravado o ID da sessão de colaboração (opcional - se não for fornecido, será utilizado 'hello_session.dat')
6) tempo de espera entre cada tentativa de acesso ao barramento (em segundos e opcional - se não for fornecido, será 1)
7) número máximo de tentativas de acesso ao barramento (opcional - se não for fornecido, será 10)

SessionMember
1) host do barramento
2) porta do barramento
3) nome de entidade
4) senha (opcional - se não for fornecida, será usado o nome de entidade)
5) arquivo contendo o ID da sessão de colaboração (opcional - se não for fornecido, será utilizado 'hello_session.dat')
6) tempo de espera entre cada tentativa de acesso ao barramento (em segundos e opcional - se não for fornecido, será 1)
7) número máximo de tentativas de acesso ao barramento (opcional - se não for fornecido, será 10)


------------------------------
---------- EXECUÇÃO ----------
------------------------------

A demo deve ser executada na seguinte ordem:

1) SessionObserver
2) SessionMember


-------------------------------
----------- EXEMPLO -----------
-------------------------------
Supondo que os jars que a demo depende estão em um diretório chamado '/openbus-sdk-java/lib':

1) java -Djava.endorsed.dirs=/openbus-sdk-java/lib/ -cp $(echo lib/*.jar | tr ' ' ':'):openbus-collaboration-demo-java-hello-observer-1.0.0.jar -Djacorb.isLocalHistoricalInterceptors=true tecgraf.openbus.services.collaboration.v1_0.SessionObserver localhost 2089 CollaborationService

2) java -Djava.endorsed.dirs=/openbus-sdk-java/lib/ -cp $(echo lib/*.jar | tr ' ' ':'):openbus-collaboration-demo-java-hello-observer-1.0.0.jar tecgraf.openbus.services.collaboration.v1_0.SessionMember localhost 2089 CollaborationService
