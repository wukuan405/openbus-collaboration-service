package tecgraf.collaboration.demo;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.InputStreamReader;

import org.omg.CORBA.ORB;
import org.omg.CORBA.ORBPackage.InvalidName;
import org.omg.PortableServer.POA;
import org.omg.PortableServer.POAHelper;

import tecgraf.collaboration.demo.util.DemoExceptionHandler;
import tecgraf.collaboration.demo.util.DemoHandlingException;
import tecgraf.collaboration.demo.util.Utils;
import tecgraf.collaboration.demo.util.Utils.DemoParams;
import tecgraf.exception.handling.ExceptionContext;
import tecgraf.exception.handling.ExceptionType;
import tecgraf.openbus.Connection;
import tecgraf.openbus.OpenBusContext;
import tecgraf.openbus.core.ORBInitializer;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationSession;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationSessionHelper;
import tecgraf.openbus.services.collaboration.v1_0.EventConsumer;
import tecgraf.openbus.services.collaboration.v1_0.EventConsumerHelper;

/**
 * Consumidor de eventos do demo Event
 * 
 * @author Tecgraf
 */
public final class ClockSubscriber {

  /** Tratador de exceção do demo */
  private static DemoExceptionHandler handler;

  /**
   * Inicializa o ORB e realiza algumas configurações do demo.
   * 
   * @return o ORB
   */
  private static ORB initORB() {
    final ORB orb = ORBInitializer.initORB();
    // - criando thread para parar e destruir o ORB ao fim da execução do processo 
    Thread shutdown = new Thread() {
      @Override
      public void run() {
        try {
          OpenBusContext context =
            (OpenBusContext) orb.resolve_initial_references("OpenBusContext");
          context.getCurrentConnection().logout();
        }
        catch (Exception e) {
          handler.process(e, ExceptionContext.BusCore);
        }
        orb.shutdown(true);
        orb.destroy();
      }
    };
    Runtime.getRuntime().addShutdownHook(shutdown);
    return orb;
  }

  /**
   * Constrói um consumidor de eventos.
   * 
   * @param orb o ORB no qual o consumidor deve ser cadastrado
   * @param context o contexto do OpenBus
   * @return o consumidor de eventos.
   */
  private static EventConsumer buildEventConsumer(ORB orb,
    OpenBusContext context) {
    try {
      POA poa = POAHelper.narrow(orb.resolve_initial_references("RootPOA"));
      poa.the_POAManager().activate();
      EventConsumerImpl consumer = new EventConsumerImpl(context);
      return EventConsumerHelper.narrow(poa.servant_to_reference(consumer));
    }
    catch (Exception e) {
      handler.process(e, ExceptionContext.Local);
      System.exit(1);
      return null;
    }
  }

  /**
   * A função principal.
   * <p>
   * Nesta função, o consumidor de eventos irá:
   * <ol>
   * <li>inicializar o ORB</li>
   * <li>construir uma conexão com o barramento OpenBus</li>
   * <li>autenticar-se junto ao barramento</li>
   * <li>recuperar a sessão de colaboração através do IOR lido do arquivo</li>
   * <li>verificar se encontrou uma referência válida da sessão</li>
   * <li>inscrever um consumidor de eventos no canal de eventos da sessão</li>
   * <li>após 15 segundos irá se desconectar do barramento, interrompendo o
   * consumo dos eventos</li>
   * </ol>
   * 
   * @param args argumentos de linha de comando
   * @throws InvalidName
   */
  public static void main(String[] args) throws InvalidName {
    DemoParams params = Utils.retrieveParams(args);
    handler = new DemoExceptionHandler(params);

    ORB orb = initORB();
    OpenBusContext context =
      (OpenBusContext) orb.resolve_initial_references("OpenBusContext");
    Connection conn = context.createConnection(params.host, params.port);
    context.setDefaultConnection(conn);

    // autentica-se no barramento
    try {
      conn.loginByPassword(params.entity, params.password.getBytes());
    }
    catch (Exception e) {
      DemoHandlingException exp =
        handler.process(e, ExceptionContext.LoginByPassword);
      // ignora a exceção se o erro foi de AlreadyLoggedIn
      if (exp.getType() != ExceptionType.AlreadyLoggedIn) {
        System.exit(1);
        return;
      }
    }

    try {
      // recupera a sessão de colaboração que foi compartilhada
      BufferedReader reader =
        new BufferedReader(new InputStreamReader(new FileInputStream(
          "session.ior")));
      String ior = reader.readLine();
      reader.close();
      CollaborationSession session =
        CollaborationSessionHelper.narrow(orb.string_to_object(ior));

      // verificando se sessão é válida
      if (!session._non_existent()) {
        // cadastrando consumidor de eventos do canal
        session.channel().subscribe(buildEventConsumer(orb, context));
        System.out.println("Consumidor de eventos cadastrado.");
      }
      else {
        System.out.println("Sessão recuperada não é válida.");
        System.exit(1);
      }
    }
    catch (Exception e) {
      handler.process(e, ExceptionContext.Service);
      System.exit(1);
      return;
    }

    System.out.println("Consumindo eventos do canal...");
    // consome eventos por 15 segundos
    try {
      Thread.sleep(15 * 1000);
    }
    catch (InterruptedException e) {
      handler.process(e, ExceptionContext.Local);
      System.exit(1);
      return;
    }
    // Deixa o processo terminar chamando ShutdownHook
    System.out.println("Finalizado o consumo de eventos do canal.");
  }
}
