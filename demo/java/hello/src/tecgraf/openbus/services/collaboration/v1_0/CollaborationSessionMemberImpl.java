package tecgraf.openbus.services.collaboration.v1_0;

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
   * Diz 'hello' e responde a novos membros da sessão.
   *
   * {@inheritDoc}
   */
  @Override
  public void sayHello(CollaborationMember newMember) {
    String hello =
      String.format("Hello %s! My name is %s.", componentName, newMember.name);
    System.out.println(hello);

    if (!newMember.name.equals(componentName)) {
      org.omg.CORBA.Object object =
        newMember.member.getFacet(CollaborationSessionMemberHelper.id());
      CollaborationSessionMember collaborationSessionMember =
        CollaborationSessionMemberHelper.narrow(object);
      collaborationSessionMember.reply(componentName);
    }
  }

  /**
   * responde a um membro da sessão.
   *
   * {@inheritDoc}
   */
  @Override
  public void reply(String name) {
    String reply = String.format("Hi %s! I am %s.", componentName, name);
    System.out.println(reply);
  }
}
