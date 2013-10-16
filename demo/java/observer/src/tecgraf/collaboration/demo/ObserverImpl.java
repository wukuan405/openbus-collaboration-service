package tecgraf.collaboration.demo;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.concurrent.atomic.AtomicBoolean;

import scs.core.IComponent;
import tecgraf.openbus.services.collaboration.v1_0.CollaborationObserverPOA;

/**
 * Observador de uma sessão de colaboração.
 * 
 * @author Tecgraf PUC-Rio
 */
public class ObserverImpl extends CollaborationObserverPOA {

  /** Formatador de data */
  private DateFormat formatter =
    new SimpleDateFormat("dd/MM/yyyy kk:mm:ss.SSS");
  /** Calendario */
  private Calendar calendar = Calendar.getInstance();
  /** Indicador se a sesão foi destruída */
  private AtomicBoolean destroyed;

  /**
   * Construtor.
   * 
   * @param destroyed atributo para indicar se a sessão foi destruída.
   */
  public ObserverImpl(AtomicBoolean destroyed) {
    this.destroyed = destroyed;
  }

  /**
   * Um novo membro entrou na sessão de colaboração.
   * 
   * {@inheritDoc}
   */
  @Override
  public void memberAdded(String name, IComponent member) {
    calendar.setTimeInMillis(System.currentTimeMillis());
    String time = formatter.format(calendar.getTime());
    System.out.println(String.format("%s: Membro '" + name
      + "' entrou  na sessão de colaboração", time, name));
  }

  /**
   * Um membro saiu da sessão de colaboração.
   * 
   * {@inheritDoc}
   */
  @Override
  public void memberRemoved(String name) {
    calendar.setTimeInMillis(System.currentTimeMillis());
    String time = formatter.format(calendar.getTime());
    System.out.println(String.format(
      "%s: Membro '%s' saiu da sessão de colaboração", time, name));
  }

  /**
   * A sessão de colaboração deixou de existir.
   * 
   * {@inheritDoc}
   */
  @Override
  public void destroyed() {
    calendar.setTimeInMillis(System.currentTimeMillis());
    String time = formatter.format(calendar.getTime());
    System.out.println(String.format(
      "%s: A sessão de colaboração foi finalizada", time));
    destroyed.set(true);
    synchronized (destroyed) {
      destroyed.notifyAll();
    }
  }
}
