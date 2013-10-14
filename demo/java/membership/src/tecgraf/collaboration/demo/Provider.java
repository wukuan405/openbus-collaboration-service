package tecgraf.collaboration.demo;

import java.io.FileOutputStream;
import java.io.PrintWriter;

import org.omg.CORBA.ORB;
import org.omg.CORBA.ORBPackage.InvalidName;
import org.omg.PortableServer.POA;
import org.omg.PortableServer.POAHelper;

import scs.core.ComponentContext;
import scs.core.ComponentId;
import scs.core.IComponent;
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
import demo.HelloHelper;

/**
 * Provedor do demo Membership.
 * 
 * @author Tecgraf
 */
public class Provider {

  /** Tratador de exceção do demo */
  private static DemoExceptionHandler handler;

  /**
   * Inicializa o ORB e realiza algumas configurações do demo.
   * 
   * @return o ORB
   */
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

  /**
   * Constrói o membro a ser adicionada à sessão de colaboração.
   * 
   * @param orb o ORB ao qual o membro deve estar associado.
   * @param context o contexto OpenBus.
   * @return o membro.
   */
  private static IComponent buildSessionMember(ORB orb, OpenBusContext context) {
    try {
      POA poa = POAHelper.narrow(orb.resolve_initial_references("RootPOA"));
      poa.the_POAManager().activate();
      ComponentContext component =
        new ComponentContext(orb, poa, new ComponentId("Provider", (byte) 1,
          (byte) 0, (byte) 0, "Java"));
      component.addFacet("Hello", HelloHelper.id(), new HelloImpl(context));
      return component.getIComponent();
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
   * Nesta função, o provedor irá:
   * <ol>
   * <li>inicializar o ORB</li>
   * <li>construir uma conexão com o barramento OpenBus</li>
   * <li>autenticar-se junto ao barramento</li>
   * <li>buscar pelo serviço de colaboração</li>
   * <li>verificar se encontrou uma referência válida do serviço</li>
   * <li>solicitar a criação de uma sessão de colaboração</li>
   * <li>criar e cadastrar um membro na sessão</li>
   * <li>salvar o IOR da sessão em um arquivo local</li>
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

    // cria a sessão de colaboração
    try {
      CollaborationSession session = collab.createCollaborationSession();
      IComponent member = buildSessionMember(orb, context);
      session.addMember("Provider's Hello", member);

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
