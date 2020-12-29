//===--- ImageInspectionELF.cpp - ELF image inspection --------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
///
/// \file
///
/// This file includes routines that interact with ld*.so on ELF-based platforms
/// to extract runtime metadata embedded in dynamically linked ELF images
/// generated by the Swift compiler.
///
//===----------------------------------------------------------------------===//

#if defined(__ELF__)

#include "ImageInspection.h"
#include "ImageInspectionELF.h"
#include <dlfcn.h>

using namespace swift;

namespace {
static const swift::MetadataSections *registered = nullptr;

void record(const swift::MetadataSections *sections) {
  if (registered == nullptr) {
    registered = sections;
    sections->next = sections->prev = sections;
  } else {
    registered->prev->next = sections;
    sections->next = registered;
    sections->prev = registered->prev;
    registered->prev = sections;
  }
}
}

void swift::initializeProtocolLookup() {
  const swift::MetadataSections *sections = registered;
  while (true) {
    const swift::MetadataSections::Range &protocols =
        sections->swift5_protocols;
    if (protocols.length)
      addImageProtocolsBlockCallbackUnsafe(
          reinterpret_cast<void *>(protocols.start), protocols.length);

    if (sections->next == registered)
      break;
    sections = sections->next;
  }
}
void swift::initializeProtocolConformanceLookup() {
  const swift::MetadataSections *sections = registered;
  while (true) {
    const swift::MetadataSections::Range &conformances =
        sections->swift5_protocol_conformances;
    if (conformances.length)
      addImageProtocolConformanceBlockCallbackUnsafe(
          reinterpret_cast<void *>(conformances.start), conformances.length);

    if (sections->next == registered)
      break;
    sections = sections->next;
  }
}

void swift::initializeTypeMetadataRecordLookup() {
  const swift::MetadataSections *sections = registered;
  while (true) {
    const swift::MetadataSections::Range &type_metadata =
        sections->swift5_type_metadata;
    if (type_metadata.length)
      addImageTypeMetadataRecordBlockCallbackUnsafe(
          reinterpret_cast<void *>(type_metadata.start), type_metadata.length);

    if (sections->next == registered)
      break;
    sections = sections->next;
  }
}

void swift::initializeDynamicReplacementLookup() {
}

// As ELF images are loaded, ImageInspectionInit:sectionDataInit() will call
// addNewDSOImage() with an address in the image that can later be used via
// dladdr() to dlopen() the image after the appropriate initialize*Lookup()
// function has been called.
SWIFT_RUNTIME_EXPORT
void swift_addNewDSOImage(const void *addr) {
  const swift::MetadataSections *sections =
      static_cast<const swift::MetadataSections *>(addr);

  record(sections);

  const auto &protocols_section = sections->swift5_protocols;
  const void *protocols =
      reinterpret_cast<void *>(protocols_section.start);
  if (protocols_section.length)
    addImageProtocolsBlockCallback(protocols, protocols_section.length);

  const auto &protocol_conformances = sections->swift5_protocol_conformances;
  const void *conformances =
      reinterpret_cast<void *>(protocol_conformances.start);
  if (protocol_conformances.length)
    addImageProtocolConformanceBlockCallback(conformances,
                                             protocol_conformances.length);

  const auto &type_metadata = sections->swift5_type_metadata;
  const void *metadata = reinterpret_cast<void *>(type_metadata.start);
  if (type_metadata.length)
    addImageTypeMetadataRecordBlockCallback(metadata, type_metadata.length);

  const auto &dynamic_replacements = sections->swift5_replace;
  const auto *replacements =
      reinterpret_cast<void *>(dynamic_replacements.start);
  if (dynamic_replacements.length) {
    const auto &dynamic_replacements_some = sections->swift5_replac2;
    const auto *replacements_some =
      reinterpret_cast<void *>(dynamic_replacements_some.start);
    addImageDynamicReplacementBlockCallback(
        replacements, dynamic_replacements.length, replacements_some,
        dynamic_replacements_some.length);
  }
}

int swift::lookupSymbol(const void *address, SymbolInfo *info) {
  Dl_info dlinfo;
  if (dladdr(address, &dlinfo) == 0) {
    return 0;
  }

  info->fileName = dlinfo.dli_fname;
  info->baseAddress = dlinfo.dli_fbase;
  info->symbolName.reset(dlinfo.dli_sname);
  info->symbolAddress = dlinfo.dli_saddr;
  return 1;
}

// This is only used for backward deployment hooks, which we currently only support for
// MachO. Add a stub here to make sure it still compiles.
void *swift::lookupSection(const char *segment, const char *section, size_t *outSize) {
  return nullptr;
}

#endif // defined(__ELF__)