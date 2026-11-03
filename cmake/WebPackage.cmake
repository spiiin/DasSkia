# Shared script/data package for interpreter, strict runner and WASM AOT generator.
function(dasskia_web_package target)
    target_link_options(${target} PRIVATE -sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=128MB
        -sSTACK_SIZE=8MB -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 -sFULL_ES3=1
        -sFORCE_FILESYSTEM=1
        "SHELL:--preload-file ${PROJECT_SOURCE_DIR}/dasskia@/dasskia"
        "SHELL:--preload-file ${PROJECT_SOURCE_DIR}/examples@/examples"
        "SHELL:--preload-file ${PROJECT_SOURCE_DIR}/tests@/tests"
        "SHELL:--preload-file ${PROJECT_SOURCE_DIR}/assets@/assets"
        "SHELL:--preload-file ${PROJECT_SOURCE_DIR}/third_party/daScript/daslib@/daslib")
    file(GLOB_RECURSE inputs CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/dasskia/*.das"
        "${PROJECT_SOURCE_DIR}/examples/*.das" "${PROJECT_SOURCE_DIR}/tests/*.das"
        "${PROJECT_SOURCE_DIR}/assets/*" "${PROJECT_SOURCE_DIR}/third_party/daScript/daslib/*.das")
    if(DASSKIA_WITH_DASSDL3)
        target_link_options(${target} PRIVATE "SHELL:--preload-file ${DASSKIA_DASSDL3_ROOT}/dassdl3@/dassdl3")
        file(GLOB sdl_inputs CONFIGURE_DEPENDS "${DASSKIA_DASSDL3_ROOT}/dassdl3/*.das")
        list(APPEND inputs ${sdl_inputs})
    endif()
    set_property(TARGET ${target} APPEND PROPERTY LINK_DEPENDS ${inputs})
endfunction()
