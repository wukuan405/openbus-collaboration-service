package tecgraf.collaboration.demo.util;

import tecgraf.exception.handling.ExceptionContext;
import tecgraf.exception.handling.ExceptionType;
import tecgraf.exception.handling.HandlingException;

/**
 * Wrapper de exceções específicos para os demos de colaboração. Esta classe
 * esta associada a enumeração {@link ExceptionType}.
 * 
 * @author Tecgraf
 */
public class DemoHandlingException extends HandlingException<ExceptionType> {

  /**
   * Construtor.
   * 
   * @param exception a exceção a ser tratada
   * @param context o contexto no qual a exceção ocorreu.
   */
  public DemoHandlingException(Exception exception, ExceptionContext context) {
    super(exception, context);
  }

  /**
   * {@inheritDoc}
   */
  @Override
  protected ExceptionType getTypeFromException(Exception exception) {
    return ExceptionType.getType(exception);
  }

}