using System;

namespace ClearMeasure.Bootcamp.Core
{
    public interface IRequest<out TResponse>
    {
         
    }
    public interface RequestMatcher
    {
        Func<IRequest, bool> IsMatch { get; set; }
        Type HandlerType { get; set; }
    }

    public interface IRequestHandler
    {
        RequestMatcher CanHandle();
        void Handle(IRequest request);
    }
    public interface IRequest { }
    public interface IQuery<TResponse> : IRequest
    {
        TResponse Result { get; set; }
    }

    public interface ICommand : IRequest
    {

    }

    public interface IEvent : IRequest { }
}