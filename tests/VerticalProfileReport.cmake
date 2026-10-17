execute_process(
  COMMAND "${CLI}" --input "${CASE}" --verbose
  RESULT_VARIABLE result
  OUTPUT_VARIABLE report
  ERROR_VARIABLE error)
if(NOT result EQUAL 0)
  message(FATAL_ERROR "Verbose Case B failed: ${result}\n${error}")
endif()
foreach(required IN ITEMS "Cell occupancy" "Plane crossing" "OccSum" "Air = initial-volume-weighted"
    "APPlume" "Spray Mass Balance" "not cumulative deposited mass")
  string(FIND "${report}" "${required}" position)
  if(position EQUAL -1)
    message(FATAL_ERROR "Report is missing: ${required}")
  endif()
endforeach()
string(FIND "${report}" "TotDep" position)
if(NOT position EQUAL -1)
  message(FATAL_ERROR "Report still contains the invalid TotDep row")
endif()

execute_process(
  COMMAND "${CLI}" --list-dsd-profiles --dsd-library "${LIBRARY}"
  RESULT_VARIABLE result
  OUTPUT_VARIABLE listing
  ERROR_VARIABLE error)
if(NOT result EQUAL 0)
  message(FATAL_ERROR "DSD listing failed: ${result}\n${error}")
endif()
string(FIND "${listing}" "Test fixture only" position)
if(position EQUAL -1)
  message(FATAL_ERROR "DSD listing did not include the test profile")
endif()
