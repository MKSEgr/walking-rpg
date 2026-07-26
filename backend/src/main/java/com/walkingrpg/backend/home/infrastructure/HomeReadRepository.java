package com.walkingrpg.backend.home.infrastructure;

import java.time.LocalDate;

import com.walkingrpg.backend.home.domain.HomeRuntimeState;

public interface HomeReadRepository {

    HomeRuntimeState findState(
            String userId,
            LocalDate localDate,
            String expeditionId
    );
}
