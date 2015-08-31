using System;
using ClearMeasure.Bootcamp.Core.Features.Workflow;
using ClearMeasure.Bootcamp.Core.Services;

namespace ClearMeasure.Bootcamp.Core.Model.ExpenseReportWorkflow
{
    public abstract class StateCommandBase : IStateCommand
    {
        protected StateCommandBase()
        {
        }

        public abstract string TransitionVerbPastTense { get; }

        public abstract ExpenseReportStatus GetBeginStatus();
        public abstract string TransitionVerbPresentTense { get; }

        public bool IsValid(ExecuteTransitionCommand transitionCommand)
        {
            bool beginStatusMatches = transitionCommand.Report2.Status.Equals(GetBeginStatus());
            bool currentUserIsCorrectRole = userCanExecute(transitionCommand.CurrentUser2, transitionCommand.Report2);
            return beginStatusMatches && currentUserIsCorrectRole;
        }

        public ExecuteTransitionResult Execute(ExecuteTransitionCommand transitionCommand)
        {
            preExecute(transitionCommand);
            string currentUserFullName = transitionCommand.CurrentUser2.GetFullName();
            transitionCommand.Report2.ChangeStatus(transitionCommand.CurrentUser2, transitionCommand.CurrentDate2, GetBeginStatus(), GetEndStatus());

            string loweredTransitionVerb = TransitionVerbPastTense.ToLower();
            string reportNumber = transitionCommand.Report2.Number;
            string message = string.Format("You have {0} work order {1}", loweredTransitionVerb, reportNumber);
            string debugMessage = string.Format("{0} has {1} work order {2}", currentUserFullName, loweredTransitionVerb,
                reportNumber);

            return new ExecuteTransitionResult {NewStatus = GetEndStatus().FriendlyName
                , NextStep = NextStep.Edit, Action = debugMessage, Message = message };
        }

        public bool Matches(string commandName)
        {
            return TransitionVerbPresentTense == commandName;
        }

        protected abstract ExpenseReportStatus GetEndStatus();
        protected abstract bool userCanExecute(Employee currentUser, ExpenseReport report);

        protected virtual void preExecute(ExecuteTransitionCommand transitionCommand)
        {
        }
    }
}