package tecgraf.openbus.services.collaboration.v1_0;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;

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

import scs.core.exception.SCSException;
import tecgraf.openbus.assistant.Assistant;
import tecgraf.openbus.assistant.AssistantParams;
import tecgraf.openbus.core.v2_0.services.ServiceFailure;
import tecgraf.openbus.core.v2_0.services.access_control.InvalidRemoteCode;
import tecgraf.openbus.core.v2_0.services.access_control.NoLoginCode;
import tecgraf.openbus.core.v2_0.services.access_control.UnknownBusCode;
import tecgraf.openbus.core.v2_0.services.access_control.UnverifiedLoginCode;
import tecgraf.openbus.demo.util.Utils;
import tecgraf.openbus.exception.AlreadyLoggedIn;

/**
 * Cliente do demo Clock
 *
 * @author Tecgraf
 */
public final class ClockClient {

  private static String host;
  private static int port;
  private static String entity;
  private static String password;
  private static String file;
  private static int interval = 1;
  private static int retries = 10;

  // sessão do serviço de colaboração
  private static CollaborationSession collaborationSession;

  // cookie do consumidor de eventos
  private static int channelConsumer;

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
        "\n  - [file] = é o arquivo contendo o ID da sessão de colaboração"
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
    // - arquivo contendo o ID da sessão de colaboração (opcional)
    file = "clock_session.dat";
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
        if (collaborationSession != null) {
          try {
            collaborationSession.channel().unsubscribe(channelConsumer);
          }
          // bus core
          catch (ServiceFailure e) {
            System.err.println(String
              .format("falha severa no barramento em %s:%s : %s", host, port,
                e.message));
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
        }
        assist.shutdown();
        orb.shutdown(true);
        orb.destroy();
      }
    };
    Runtime.getRuntime().addShutdownHook(shutdown);

    // - ativando o POA
    poa = POAHelper.narrow(orb.resolve_initial_references("RootPOA"));
    poa.the_POAManager().activate();

    Thread enterCollaborationSession = new Thread() {
      @Override
      public void run() {
        try {
          enterCollaborationSession();
        }
        catch (IOException e) {
          System.err
            .println(String.format("erro ao ler do arquivo '%s'", file));
          System.exit(1);
          return;
        }
      }
    };
    enterCollaborationSession.start();
  }

  public static EventConsumer makeEventConsumer() {
    Servant servant = new EventConsumerImpl();
    try {
      // cria um consumidor de eventos
      return EventConsumerHelper.narrow(poa.servant_to_reference(servant));
    }
    catch (ServantNotActive e) {
      System.err.println("consumidor de eventos não está ativo");
    }
    catch (WrongPolicy e) {
      System.err.println("falha na criação do consumidor de eventos");
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
    return null;
  }

  private static void enterCollaborationSession() throws IOException {
    boolean failed;
    do {
      failed = true;
      try {
        // entra na sessão de colaboração
        FileReader freader = new FileReader(file);
        BufferedReader breader = new BufferedReader(freader);
        collaborationSession =
          CollaborationSessionHelper.narrow(orb.string_to_object(breader
            .readLine()));
        breader.close();
        channelConsumer =
          collaborationSession.channel().subscribe(makeEventConsumer());
        failed = false;
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
