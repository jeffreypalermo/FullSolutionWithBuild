aws cloudformation create-stack --stackname ClearMeasureBootcamp  \
    --template-body file:///src/AWS/BootCamp.template \
    --parameters file:///src/AWS/cf_parameters.json