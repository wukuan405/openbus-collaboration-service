package tecgraf.openbus.services.collaboration.v1_0;

import org.omg.CORBA.COMM_FAILURE;
import org.omg.CORBA.NO_PERMISSION;
import org.omg.CORBA.TRANSIENT;

import scs.core.IComponent;
import tecgraf.openbus.core.v2_0.services.ServiceFailure;
import tecgraf.openbus.core.v2_0.services.access_control.InvalidRemoteCode;
import tecgraf.openbus.core.v2_0.services.access_control.NoLoginCode;
import tecgraf.openbus.core.v2_0.services.access_control.UnknownBusCode;
import tecgraf.openbus.core.v2_0.services.access_control.UnverifiedLoginCode;

/**
 * Observador de uma sessão de colaboração.
 *
 * @author Tecgraf PUC-Rio
 */
public class CollaborationSessionObserverImpl extends CollaborationObserverPOA {
  /**
   * Sessão do serviço de colaboração.
   */
  private CollaborationSession collaborationSession;

  /**
   * Construtor.
   *
   * @param collaborationSession Sessão do serviço de colaboração.
   */
  public CollaborationSessionObserverImpl(
    CollaborationSession collaborationSession) {
    this.collaborationSession = collaborationSession;
  }

  /**
   * Um novo membro entrou na sessão de colaboração.
   *
   * {@inheritDoc}
   */
  @Override
  public void memberAdded(String name, IComponent member) {
    System.out.println("Adicionado um novo membro '" + name
      + "' na sessão de colaboração.");

    try {
      // diz 'hello' para todos os outros membros da sessão
      tecgraf.openbus.services.collaboration.v1_0.CollaborationMember[] collaborationMember =
        collaborationSession.getMembers();
      for (CollaborationMember m : collaborationMember) {
        if (!m.name.equals(name)) {
          org.omg.CORBA.Object object =
            m.member.getFacet(CollaborationSessionMemberHelper.id());
          CollaborationSessionMember collaborationSessionMember =
            CollaborationSessionMemberHelper.narrow(object);
          collaborationSessionMember.sayHello(name);
        }
      }
    }
    // bus core
    catch (ServiceFailure e) {
      System.err.println("falha severa no barramento");
    }
    catch (TRANSIENT e) {
      System.err.println("o barramento esta inacessível no momento");
    }
    catch (COMM_FAILURE e) {
      System.err
        .println("falha de comunicação ao acessar serviços núcleo do barramento");
    }
    catch (NO_PERMISSION e) {
      switch (e.minor) {
        case NoLoginCode.value:
          System.err.println("não há um login de válido no momento");
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
  }

  /**
   * Um membro saiu da sessão de colaboração.
   *
   * {@inheritDoc}
   */
  @Override
  public void memberRemoved(String name) {
    System.out.println("Removido o membro '" + name
      + "' da sessão de colaboração");
  }

  /**
   * A sessão de colaboração deixou de existir.
   *
   * {@inheritDoc}
   */
  @Override
  public void destroyed() {
    System.out.println("A sessão de colaboração foi finalizada");
  }
}
