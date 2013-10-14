package tecgraf.collaboration.demo;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.util.concurrent.atomic.AtomicBoolean;

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
import tecgraf.openbus.core.v2_0.services.offer_registry.ServiceOfferDesc;
import tecgraf.openbus.core.v2_0.services.offer_registry.ServiceProperty;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationObserver;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationObserverHelper;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationRegistry;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationRegistryHelper;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationSession;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationSessionHelper;

/**
 * Observador do demo Observer
 * <p>
 * Adiciona um observador na sessão de colaboração.
 * 
 * @author Tecgraf
 */
public final class Observer {

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
   * Constrói o observador da sessão de colaboração.
   * 
   * @param orb o ORB ao qual o observador deve estar associado
   * @param destroyed atributo para indicar se a sessão foi destruída
   * @return o observador.
   */
  private static CollaborationObserver buildObserver(ORB orb,
    AtomicBoolean destroyed) {
    try {
      POA poa = POAHelper.narrow(orb.resolve_initial_references("RootPOA"));
      poa.the_POAManager().activate();
      ObserverImpl observerImpl = new ObserverImpl(destroyed);
      return CollaborationObserverHelper.narrow(poa
        .servant_to_reference(observerImpl));
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
   * Nesta função, o observador irá:
   * <ol>
   * <li>inicializar o ORB</li>
   * <li>construir uma conexão com o barramento OpenBus</li>
   * <li>autenticar-se junto ao barramento</li>
   * <li>recuperar a sessão de colaboração através do IOR lido do arquivo</li>
   * <li>verificar se encontrou uma referência válida da sessão</li>
   * <li>cadastrar um observador na sessão de colaboração</li>
   * <li>observar a sessão de colaboração enquanto a sessão não é destruída</li>
   * <li>desconectar do barramento</li>
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
      DemoHandlingException excep =
        handler.process(e, ExceptionContext.LoginByPassword);
      if (excep.getType() != ExceptionType.AlreadyLoggedIn) {
        System.exit(1);
        return;
      }
    }

    ServiceOfferDesc[] services;
    // busca por serviço
    try {
      ServiceProperty[] properties = new ServiceProperty[1];
      properties[0] =
        new ServiceProperty("openbus.component.interface",
          CollaborationRegistryHelper.id());
      services = context.getOfferRegistry().findServices(properties);
    }
    catch (Exception e) {
      handler.process(e, ExceptionContext.BusCore);
      System.exit(1);
      return;
    }

    CollaborationRegistry collab = null;
    // analisa as ofertas encontradas
    for (ServiceOfferDesc offerDesc : services) {
      try {
        if (!offerDesc.service_ref._non_existent()) {
          org.omg.CORBA.Object helloObj =
            offerDesc.service_ref.getFacet(CollaborationRegistryHelper.id());
          if (helloObj != null) {
            collab = CollaborationRegistryHelper.narrow(helloObj);
            System.out.println("o serviço foi encontrado!");
            break;
          }
          else {
            System.out
              .println("o serviço encontrado não provê a faceta ofertada");
          }
        }
      }
      catch (Exception e) {
        handler.process(e, ExceptionContext.Service);
        System.out.println("descartando oferta inválida");
      }
    }

    if (collab == null) {
      System.out.println("nenhum serviço válido foi encontrado.");
      System.exit(1);
      return;
    }

    AtomicBoolean destroyed = new AtomicBoolean(false);
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
        // adiciona observador
        CollaborationObserver observer = buildObserver(orb, destroyed);
        session.subscribeObserver(observer);
        System.out.println("observador registrado...");
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

    synchronized (destroyed) {
      try {
        if (!destroyed.get()) {
          destroyed.wait();
        }
        System.out
          .println("Sessão destruída. Terminando processo observador...");
      }
      catch (InterruptedException e) {
        handler.process(e, ExceptionContext.Local);
        System.exit(1);
        return;
      }
    }
  }
}
