package tecgraf.collaboration.demo;

import java.io.FileOutputStream;
import java.io.PrintWriter;

import org.omg.CORBA.ORB;
import org.omg.CORBA.ORBPackage.InvalidName;

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
import tecgraf.openbus.services.collaboration.v1_0.CollaborationRegistry;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationRegistryHelper;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationSession;

public class Server {

  private static DemoExceptionHandler handler;

  private static ORB initORB() {
    final ORB orb = ORBInitializer.initORB();
    // - disparando a thread para que o ORB atenda requisições
    Thread run = new Thread() {
      @Override
      public void run() {
        orb.run();
      }
    };
    run.start();
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

    // cria a sessão de colaboração
    try {
      CollaborationSession session = collab.createCollaborationSession();
      System.out.println("sessão de colaboração gerada...");
      // disponibilizando uma referência para a sessão criada    
      PrintWriter pw = new PrintWriter(new FileOutputStream("session.ior"));
      pw.println(orb.object_to_string(session));
      pw.close();
    }
    catch (Exception e) {
      handler.process(e, ExceptionContext.Service);
      System.exit(1);
      return;
    }

  }

}
