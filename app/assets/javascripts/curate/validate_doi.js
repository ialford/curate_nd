var validateDOIs = function(){
  'use strict';

  $('#no-doi, #mint-doi').click(function(e){
    var $target = $(e.target),
    $field  = $('#publisher');

    if ($target.attr('id') === 'mint-doi') {
      $field.attr('required', 'true');
    } else {
      $field.removeAttr('required');
    }
  });
};

$(document).ready(validateDOIs);
$(document).on('page:load', validateDOIs);
