module Node_QAP
{
	use CTypes;

  record Node_QAP
  {
    var depth: c_uint;
    var board: c_array(c_char, 4);
  };

}
