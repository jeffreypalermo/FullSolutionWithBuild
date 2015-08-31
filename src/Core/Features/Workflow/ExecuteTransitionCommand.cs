using System;
using ClearMeasure.Bootcamp.Core.Model;

namespace ClearMeasure.Bootcamp.Core.Features.Workflow
{
    public class ExecuteTransitionCommand : IRequest<ExecuteTransitionResult>
    {
        public ExpenseReport Report2 { get; set; }
        public string Command { get; set; }
        public Employee CurrentUser2 { get; set; }
        public DateTime CurrentDate2 { get; set; }

        public ExecuteTransitionCommand(ExpenseReport report, string command, Employee currentUser, DateTime currentDate, int i=0)
        {
            CurrentDate2 = currentDate;
            Report2 = report;
            Command = command;
            CurrentUser2 = currentUser;
        }

        public ExecuteTransitionCommand(){ }
    }
}