package tecgraf.exception.handling;

/**
 * Esta classe atua como um wrapper sobre as exceções específicas que desejamos
 * tratar.
 * 
 * @author Tecgraf
 * @param <T> a enumeração de tipos de exceções a serem tratadas.
 */
public abstract class HandlingException<T extends Enum<?>> {

  /** A exceção */
  private Exception theException;

  /** O tipo */
  private T theType;

  /** O contexto */
  private ExceptionContext theContext;

  /**
   * Construtor.
   * 
   * @param exception a exceção
   * @param context o contexto
   */
  public HandlingException(Exception exception, ExceptionContext context) {
    this.theException = exception;
    this.theType = getTypeFromException(exception);
    this.theContext = context;
  }

  /**
   * Recuper o tipo enum da exceção.
   * 
   * @param exception
   * @return o tipo Enum da exceção.
   */
  protected abstract T getTypeFromException(Exception exception);

  /**
   * Recupera a exceção
   * 
   * @return a exceção
   */
  public Exception getException() {
    return theException;
  }

  /**
   * Recupera o contexto
   * 
   * @return o contexto
   */
  public ExceptionContext getContext() {
    return theContext;
  }

  /**
   * Recupera o tipo da exceção
   * 
   * @return o tipo
   */
  public T getType() {
    return theType;
  }

}