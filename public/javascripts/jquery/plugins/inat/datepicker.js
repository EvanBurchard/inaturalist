// This is a VERY light wrapper around the JQueryUI datepicker plugin for use
// in iNat.
(function($){
  // Override datepicker's keybaord nav.  It makes baby jesus cry.
  $.datepicker._doKeyPress = function(e) {
    return true;
  }
  
  $.fn.iNatDatepicker = function(options) {
    $(this).width($(this).width() - 26);
    $(this).css({
      'margin-right': '10px',
      'vertical-align': 'middle'
    })
    options = options || {}
    options = $.extend({}, {
      showOn: 'both',
      buttonImage: "/images/silk/date.png",
      buttonImageOnly: true,
      showButtonPanel: true,
      showAnim: 'fadeIn',
      yearRange: "c-100:c+0",
      maxDate: '+0d',
      constrainInput: false,
      firstDay: 0,
      changeFirstDay: false,
      changeMonth: true,
      changeYear: true,
      dateFormat: 'yy-mm-dd'
    }, options)
    $(this).datepicker(options);
    $(this).next('.ui-datepicker-trigger').css({
      'vertical-align': 'middle'
    });
  };
})(jQuery);
