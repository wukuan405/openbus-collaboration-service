package tecgraf.openbus.services.collaboration.v1_0;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;

import scs.core.IComponent;

/**
 * Observador de uma sess�o de colabora��o.
 *
 * @author Tecgraf PUC-Rio
 */
public class CollaborationSessionObserverImpl extends CollaborationObserverPOA {
  /**
   * Um novo membro entrou na sess�o de colabora��o.
   *
   * {@inheritDoc}
   */
  @Override
  public void memberAdded(String name, IComponent member) {
    org.omg.CORBA.Object object =
      member.getFacet(CollaborationSessionMemberHelper.id());
    CollaborationSessionMember collaborationSessionMember =
      CollaborationSessionMemberHelper.narrow(object);
    Date date = new Date(collaborationSessionMember.getTimeInTicks());
    DateFormat formatter = new SimpleDateFormat("dd/MM/yyyy kk:mm:ss.SSS");
    System.out.println("Adicionado um novo membro '"
      + name + "' na sess�o de colabora��o em " + formatter.format(date));
  }

  /**
   * Um membro saiu da sess�o de colabora��o.
   *
   * {@inheritDoc}
   */
  @Override
  public void memberRemoved(String name) {
    System.out.println("Removido o membro '" + name
      + "' da sess�o de colabora��o");
  }

  /**
   * A sess�o de colabora��o deixou de existir.
   *
   * {@inheritDoc}
   */
  @Override
  public void destroyed() {
    System.out.println("A sess�o de colabora��o foi finalizada");
  }
}