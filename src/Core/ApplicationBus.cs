using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

namespace ClearMeasure.Bootcamp.Core
{
    public class ApplicationBus 
    {
        public static List<RequestMatcher> _handlerMatchers;
        public virtual void Send(IRequest request)
        {
            IEnumerable<Type> handlerTypes = _handlerMatchers.Where(x => x.IsMatch.Invoke(request)).Select(x=>x.HandlerType);
            foreach (var handlertype in handlerTypes)
            {
                ((IRequestHandler)Activator.CreateInstance(handlertype)).Handle(request);
            }
        }

        private RequestHandler<TResponse> GetHandler<TResponse>(IRequest<TResponse> request)
        {
            var handlerType = typeof(IRequestHandler<,>).MakeGenericType(request.GetType(), typeof(TResponse));
            var wrapperType = typeof(RequestHandler<,>).MakeGenericType(request.GetType(), typeof(TResponse));
            object handler;
            try
            {
                handler = _singleInstanceFactory(handlerType);

                if (handler == null)
                    throw new InvalidOperationException("Handler was not found for request of type " + request.GetType());
            }
            catch (Exception e)
            {
                throw new InvalidOperationException("Handler was not found for request of type " + request.GetType(), e);
            }
            var wrapperHandler = Activator.CreateInstance(wrapperType, handler);
            return (RequestHandler<TResponse>)wrapperHandler;
        }

        private abstract class RequestHandler<TResult>
        {
            public abstract TResult Handle(IRequest<TResult> message);
        }

        private class RequestHandler<TCommand, TResult> : RequestHandler<TResult> where TCommand : IRequest<TResult>
        {
            private readonly IRequestHandler<TCommand, TResult> _inner;

            public RequestHandler(IRequestHandler<TCommand, TResult> inner)
            {
                _inner = inner;
            }

            public override TResult Handle(IRequest<TResult> message)
            {
                return _inner.Handle((TCommand)message);
            }
        }
    }
}