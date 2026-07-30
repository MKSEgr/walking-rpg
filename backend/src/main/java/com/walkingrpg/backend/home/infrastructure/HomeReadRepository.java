package com.walkingrpg.backend.home.infrastructure;

import java.time.LocalDate;
import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;

public interface HomeReadRepository {

    HomeRuntimeState findState(
            String userId,
            LocalDate localDate,
            String expeditionId
    );

    Optional<ProcessedEventResolution> findPendingEventResult(
            String userId,
            String expeditionId
    );
}
