using System;
using ClearMeasure.Bootcamp.Core.Features.Workflow;
using ClearMeasure.Bootcamp.Core.Services;

namespace ClearMeasure.Bootcamp.Core.Model.ExpenseReportWorkflow
{
    public class ApprovedToSubmittedCommand : StateCommandBase
    {
        public ApprovedToSubmittedCommand() : base()
        {
        }

        public override string TransitionVerbPresentTense
        {
            get { return "Decline"; }
        }

        public override string TransitionVerbPastTense
        {
            get { return "Declined"; }
        }

        public override ExpenseReportStatus GetBeginStatus()
        {
            return ExpenseReportStatus.Approved;
        }

        protected override ExpenseReportStatus GetEndStatus()
        {
            return ExpenseReportStatus.Submitted;
        }

        protected override bool userCanExecute(Employee currentUser, ExpenseReport report)
        {
            if (report.Approver == null) return false;
            return report.Approver.CanActOnBehalf(currentUser);
        }

        protected override void preExecute(ExecuteTransitionCommand transitionCommand)
        {
            base.preExecute(transitionCommand);
            transitionCommand.Report.LastDeclined = transitionCommand.CurrentDate;
        }
    }
}