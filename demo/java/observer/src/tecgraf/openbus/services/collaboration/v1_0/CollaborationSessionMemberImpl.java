package tecgraf.openbus.services.collaboration.v1_0;

public class CollaborationSessionMemberImpl extends CollaborationSessionMemberPOA {

  @Override
  public long getTimeInTicks() {
    return System.currentTimeMillis();
  }

}
