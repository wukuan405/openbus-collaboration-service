package tecgraf.openbus.services.collaboration.v1_0;

import scs.core.IComponent;

/**
 * Observador de uma sessão de colaboração.
 * 
 * @author Tecgraf PUC-Rio
 */
public class CollaborationSessionObserverImpl extends CollaborationObserverPOA {
  /**
   * Um novo membro entrou na sessão de colaboração.
   * 
   * {@inheritDoc}
   */
  @Override
  public void memberAdded(String name, IComponent member) {
    System.out.println("Adicionado um novo membro '" + name
      + "' na sessão de colaboração.");
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
