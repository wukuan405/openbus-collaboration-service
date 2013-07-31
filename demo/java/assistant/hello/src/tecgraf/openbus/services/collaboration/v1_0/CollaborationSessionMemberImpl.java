package tecgraf.openbus.services.collaboration.v1_0;

/**
 * Implementação do componente CollaborationSessionMember
 *
 * @author Tecgraf
 */
public class CollaborationSessionMemberImpl extends
  CollaborationSessionMemberPOA {
  /**
   * Nome do componente.
   */
  private String componentName;

  /**
   * Construtor.
   *
   * @param name Nome do componente.
   */
  public CollaborationSessionMemberImpl(String componentName) {
    this.componentName = componentName;
  }

  /**
   * {@inheritDoc}
   */
  @Override
  public void sayHello(String name) {
    String hello =
      String.format("Hello %s! This is %s.", componentName, name);
    System.out.println(hello);
  }
}
