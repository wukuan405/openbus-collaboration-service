package tecgraf.openbus.services.collaboration.v1_0;

import static java.lang.Byte.parseByte;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.PrintWriter;

import org.omg.CORBA.COMM_FAILURE;
import org.omg.CORBA.NO_PERMISSION;
import org.omg.CORBA.ORB;
import org.omg.CORBA.TRANSIENT;
import org.omg.CORBA.ORBPackage.InvalidName;
import org.omg.PortableServer.POA;
import org.omg.PortableServer.POAHelper;
import org.omg.PortableServer.Servant;
import org.omg.PortableServer.POAManagerPackage.AdapterInactive;
import org.omg.PortableServer.POAPackage.ServantNotActive;
import org.omg.PortableServer.POAPackage.WrongPolicy;

import scs.core.ComponentContext;
import scs.core.ComponentId;
import scs.core.IComponent;
import scs.core.IComponentHelper;
import scs.core.exception.SCSException;
import tecgraf.collaboration.demo.util.Utils;
import tecgraf.openbus.assistant.Assistant;
import tecgraf.openbus.assistant.AssistantParams;
import tecgraf.openbus.core.v2_0.services.ServiceFailure;
import tecgraf.openbus.core.v2_0.services.access_control.InvalidRemoteCode;
import tecgraf.openbus.core.v2_0.services.access_control.NoLoginCode;
import tecgraf.openbus.core.v2_0.services.access_control.UnknownBusCode;
import tecgraf.openbus.core.v2_0.services.access_control.UnverifiedLoginCode;
import tecgraf.openbus.core.v2_0.services.offer_registry.ServiceOfferDesc;
import tecgraf.openbus.core.v2_0.services.offer_registry.ServiceProperty;
import tecgraf.openbus.exception.AlreadyLoggedIn;

/**
 * Cria a sessão do serviço de colaboração e adiciona um observador
 * 
 * @author Tecgraf
 */
public final class SessionObserver {

  private static String host;
  private static int port;
  private static String entity;
  private static String password;
  private static String file;
  private static int interval = 1;
  private static int retries = 10;

  // sessão do serviço de colaboração
  private static CollaborationSession collaborationSession;

  // identificador do observador
  private static int collaborationObserver;

  // nome do componente do membro da sessão de colaboração
  private static String componentName = "session_observer";

  private static ORB orb;
  private static POA poa;
  private static Assistant assist;

  /**
   * Função principal.
   * 
   * @param args argumentos.
   * @throws InvalidName
   * @throws AdapterInactive
   * @throws SCSException
   * @throws AlreadyLoggedIn
   * @throws ServiceFailure
   */
  public static void main(String[] args) throws InvalidName, AdapterInactive,
    SCSException, AlreadyLoggedIn, ServiceFailure {
    // verificando parametros de entrada
    if (args.length < 3) {
      String params = "[file] [interval] [retries]";
      String desc =
        "\n  - [file] = é o arquivo onde será gravado o ID da sessão de colaboração"
          + "\n  - [interval] = tempo de espera entre tentativas de acesso ao barramento."
          + " Valor padrão é '1'"
          + "\n  - [retries] = número máximo de tentativas de acesso ao"
          + " barramento em virtude de falhas. Valor padrão é '10'";
      System.out.println(String.format(Utils.clientUsage, params, desc));
      System.exit(1);
      return;
    }
    // - host
    host = args[0];
    // - porta
    try {
      port = Integer.parseInt(args[1]);
    }
    catch (NumberFormatException e) {
      System.out.println(Utils.port);
      System.exit(1);
      return;
    }
    // - entidade
    entity = args[2];
    // - senha (opcional)
    password = entity;
    if (args.length > 3) {
      password = args[3];
    }
    // - arquivo onde será gravado o ID da sessão de colaboração (opcional)
    file = "hello_session.dat";
    if (args.length > 4) {
      file = args[4];
    }
    // - intervalo entre falhas (opcional)
    if (args.length > 5) {
      try {
        interval = Integer.parseInt(args[5]);
      }
      catch (NumberFormatException e) {
        System.out.println("Valor de [interval] deve ser um número");
        System.exit(1);
        return;
      }
    }
    // - número máximo de tentativas
    if (args.length > 6) {
      try {
        retries = Integer.parseInt(args[6]);
      }
      catch (NumberFormatException e) {
        System.out.println("Valor de [retries] deve ser um número");
        System.exit(1);
        return;
      }
    }

    // recuperando o assistente
    AssistantParams params = new AssistantParams();
    params.interval = interval;
    assist =
      Assistant.createWithPassword(host, port, entity, password.getBytes(),
        params);
    orb = assist.orb();
    // - disparando a thread para que o ORB atenda requisições
    Thread run = new Thread() {
      @Override
      public void run() {
        orb.run();
      }
    };
    run.start();

    // - criando thread para parar e destruir o ORB ao fim da execução do processo
    final Thread shutdown = new Thread() {
      @Override
      public void run() {
        try {
          collaborationSession.removeMember(componentName);
          collaborationSession.unsubscribeObserver(collaborationObserver);
        }
        // bus core
        catch (ServiceFailure e) {
          System.err.println(String.format(
            "falha severa no barramento em %s:%s : %s", host, port, e.message));
        }
        catch (TRANSIENT e) {
          System.err.println(String.format(
            "o barramento em %s:%s esta inacessível no momento", host, port));
        }
        catch (COMM_FAILURE e) {
          System.err
            .println("falha de comunicação ao acessar serviços núcleo do barramento");
        }
        catch (NO_PERMISSION e) {
          if (e.minor == NoLoginCode.value) {
            System.err.println(String.format(
              "não há um login de '%s' válido no momento", entity));
          }
        }
        // remove o arquivo com o ID da sessão de colaboração
        File f = new File(file);
        f.delete();
        assist.shutdown();
        orb.shutdown(true);
        orb.destroy();
      }
    };
    Runtime.getRuntime().addShutdownHook(shutdown);

    // - ativando o POA
    poa = POAHelper.narrow(orb.resolve_initial_references("RootPOA"));
    poa.the_POAManager().activate();

    Thread createCollaborationSession = new Thread() {
      @Override
      public void run() {
        try {
          createCollaborationSession();
        }
        catch (FileNotFoundException e) {
          System.err.println(String.format("erro ao escrever no arquivo '%s'",
            file));
          System.exit(1);
          return;
        }
      }
    };
    createCollaborationSession.start();
  }

  /**
   * Cria um observador de sessão de colaboração.
   * 
   * @return o observador.
   */
  public static CollaborationObserver makeCollaborationSessionObserver() {
    Servant servant =
      new CollaborationSessionObserverImpl(collaborationSession);
    try {
      return CollaborationObserverHelper.narrow(poa
        .servant_to_reference(servant));
    }
    catch (ServantNotActive e) {
      System.err.println("observador da sessão de colaboração não está ativo");
    }
    catch (WrongPolicy e) {
      System.err
        .println("falha na criação do observador da sessão de colaboração");
    }
    // bus core
    catch (TRANSIENT e) {
      System.err.println(String.format(
        "o barramento em %s:%s esta inacessível no momento", host, port));
    }
    catch (COMM_FAILURE e) {
      System.err
        .println("falha de comunicação ao acessar serviços núcleo do barramento");
    }
    catch (NO_PERMISSION e) {
      if (e.minor == NoLoginCode.value) {
        System.err.println(String.format(
          "não há um login de '%s' válido no momento", entity));
      }
    }
    return null;
  }

  /**
   * Cria o componente do membro de uma sessão de colaboração. O componente
   * possui a faceta CollaborationSessionMember que permite que os outros
   * membros da sessão possam interagir com ele através dessa faceta.
   * 
   * @return O contexto do componente SCS.
   * @throws SCSException Falha na criação do serviço
   */
  private static IComponent createCollaborationSessionMember()
    throws SCSException {
    ComponentContext component = createComponentContext(componentName, "1.0.0");
    component.addFacet(CollaborationSessionMemberFacet.value,
      CollaborationSessionMemberHelper.id(),
      new CollaborationSessionMemberImpl(componentName));
    org.omg.CORBA.Object obj = component.getIComponent();
    return IComponentHelper.narrow(obj);
  }

  /**
   * Cria um contexto de componente SCS.
   * 
   * @param componentName o nome do componente
   * @param componentVersion a versão do componente
   * @return O contexto do componente SCS.
   * @throws SCSException Erro no SCS
   */
  private static ComponentContext createComponentContext(String componentName,
    String componentVersion) throws SCSException {
    final String[] tmp = componentVersion.split("[\\.]");
    byte major = parseByte(tmp[0]);
    byte minor = tmp.length >= 2 ? parseByte(tmp[1]) : 0;
    byte patch = tmp.length >= 3 ? parseByte(tmp[2]) : 0;
    ComponentId componentId =
      new ComponentId(componentName, major, minor, patch, "Java");
    ComponentContext component = new ComponentContext(orb, poa, componentId);
    return component;
  }

  private static void createCollaborationSession() throws FileNotFoundException {
    boolean failed;
    do {
      ServiceOfferDesc[] services;
      failed = true;
      try {
        // busca pelo serviço de colaboração
        ServiceProperty[] properties = new ServiceProperty[1];
        properties[0] =
          new ServiceProperty("openbus.offer.entity",
            CollaborationServiceName.value);
        services = assist.findServices(properties, interval);

        // analiza as ofertas encontradas
        for (ServiceOfferDesc offerDesc : services) {
          org.omg.CORBA.Object collaborationRegistryObj =
            offerDesc.service_ref.getFacet(CollaborationRegistryHelper.id());
          if (collaborationRegistryObj == null) {
            System.out
              .println("o serviço encontrado não provê a faceta ofertada");
            continue;
          }
          // cria uma sessão de colaboração
          CollaborationRegistry collaborationRegistry =
            CollaborationRegistryHelper.narrow(collaborationRegistryObj);
          collaborationSession =
            collaborationRegistry.createCollaborationSession();
          collaborationObserver =
            collaborationSession
              .subscribeObserver(makeCollaborationSessionObserver());
          collaborationSession.addMember(componentName,
            createCollaborationSessionMember());

          // grava o ID da sessão de colaboração
          PrintWriter out = new PrintWriter(file);
          out.println(orb.object_to_string(collaborationSession));
          out.close();
        }
        failed = false;
      }
      catch (NameInUse e) {
        System.err.println("já existe um membro com o mesmo nome");
        break;
      }
      catch (SCSException e) {
        System.err.println("falha na criação do serviço");
        break;
      }
      // bus core
      catch (ServiceFailure e) {
        System.err.println(String.format(
          "falha severa no barramento em %s:%s : %s", host, port, e.message));
      }
      catch (TRANSIENT e) {
        System.err.println(String.format(
          "o barramento em %s:%s esta inacessível no momento", host, port));
      }
      catch (COMM_FAILURE e) {
        System.err
          .println("falha de comunicação ao acessar serviços núcleo do barramento");
      }
      catch (NO_PERMISSION e) {
        switch (e.minor) {
          case NoLoginCode.value:
            System.err.println(String.format(
              "não há um login de '%s' válido no momento", entity));
            break;
          case UnknownBusCode.value:
            System.err
              .println("o serviço encontrado não está mais logado ao barramento");
            break;
          case UnverifiedLoginCode.value:
            System.err
              .println("o serviço encontrado não foi capaz de validar a chamada");
            break;
          case InvalidRemoteCode.value:
            System.err
              .println("integração do serviço encontrado com o barramento está incorreta");
            break;
        }
      }
      // erros inesperados
      catch (Throwable e) {
        System.err.println("Erro inesperado durante a busca de serviços");
        e.printStackTrace();
        System.exit(1);
        return;
      }
    } while (failed && retry());
  }

  public static boolean retry() {
    if (retries > 0) {
      retries--;
      try {
        Thread.sleep(interval * 1000);
      }
      catch (InterruptedException e) {
        // não faz nada
      }
      return true;
    }
    System.exit(1);
    return false;
  }
}
